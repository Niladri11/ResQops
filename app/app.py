from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time
import uuid
import datetime
import os
import psycopg2
from psycopg2.extras import RealDictCursor

app = Flask(__name__)

# ── Prometheus Metrics ──────────────────────────────────────────────────────
REQUEST_COUNT = Counter(
    'resqops_request_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'resqops_request_latency_seconds',
    'Request latency in seconds',
    ['endpoint']
)

APPOINTMENT_COUNT = Counter(
    'resqops_appointments_created_total',
    'Total appointments created'
)

DB_CONNECTION_FAILURES = Counter(
    'resqops_db_connection_failures_total',
    'Total DB connection failures'
)

# ── DB Config from Environment Variables ────────────────────────────────────
# These are injected via docker run -e or EKS secrets — never hardcoded
DB_HOST     = os.environ.get("DB_HOST", "localhost")
DB_NAME     = os.environ.get("DB_NAME", "resqops_db")
DB_USER     = os.environ.get("DB_USER", "resqops_admin")
DB_PASS     = os.environ.get("DB_PASS", "")
DB_PORT     = os.environ.get("DB_PORT", "5432")
APP_REGION  = os.environ.get("AWS_REGION", "us-east-1")

# ── DB Connection Helper ─────────────────────────────────────────────────────
def get_db():
    """
    Opens a new DB connection.
    RealDictCursor returns rows as dicts instead of tuples
    so you get {"id": "abc", "patient_name": "Ravi"} not ("abc", "Ravi")
    """
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASS,
            port=DB_PORT,
            connect_timeout=5          # fail fast if DB is unreachable
        )
        return conn
    except psycopg2.OperationalError as e:
        DB_CONNECTION_FAILURES.inc()   # Prometheus tracks this
        raise e

def check_db_connection():
    """
    Returns True/False — used by /ready endpoint.
    Does NOT raise an exception.
    """
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT 1;")       # lightest possible query
        conn.close()
        return True
    except Exception:
        return False

# ── DB Table Initialization ──────────────────────────────────────────────────
def init_db():
    """
    Creates the appointments table if it doesn't exist.
    Runs once on app startup.
    """
    conn = get_db()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS appointments (
            id            VARCHAR(8) PRIMARY KEY,
            patient_name  VARCHAR(100) NOT NULL,
            doctor        VARCHAR(100) NOT NULL,
            department    VARCHAR(100) NOT NULL,
            date          VARCHAR(20)  NOT NULL,
            time          VARCHAR(20)  NOT NULL,
            status        VARCHAR(20)  NOT NULL DEFAULT 'pending',
            created_at    TIMESTAMP    NOT NULL DEFAULT NOW()
        );
    """)

    # Seed some data only if table is empty
    cur.execute("SELECT COUNT(*) FROM appointments;")
    count = cur.fetchone()[0]

    if count == 0:
        seed_data = [
            ("a1b2c3d4", "Ravi Kumar",  "Dr. Sharma", "Cardiology",   "2025-04-10", "10:30 AM", "confirmed"),
            ("e5f6g7h8", "Priya Das",   "Dr. Mehta",  "Neurology",    "2025-04-11", "02:00 PM", "confirmed"),
            ("i9j0k1l2", "Arjun Singh", "Dr. Reddy",  "Orthopedics",  "2025-04-12", "11:00 AM", "pending"),
        ]
        for row in seed_data:
            cur.execute("""
                INSERT INTO appointments (id, patient_name, doctor, department, date, time, status)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (id) DO NOTHING;
            """, row)

    conn.commit()
    conn.close()
    print("✅ DB initialized successfully")

# ── Middleware: track latency on every request ───────────────────────────────
@app.before_request
def start_timer():
    request.start_time = time.time()

@app.after_request
def track_metrics(response):
    latency = time.time() - request.start_time
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.path,
        status=response.status_code
    ).inc()
    REQUEST_LATENCY.labels(endpoint=request.path).observe(latency)
    return response

# ── Routes ───────────────────────────────────────────────────────────────────

# 1. Health check — Kubernetes liveness probe
@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        "status":    "ok",
        "service":   "resqops-api",
        "version":   "2.0.0",
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
        "region":    APP_REGION
    }), 200


# 2. Readiness check — NOW actually checks DB connection
@app.route('/ready', methods=['GET'])
def ready():
    db_ok = check_db_connection()

    status_code = 200 if db_ok else 503    # 503 = Kubernetes won't route traffic here

    return jsonify({
        "status": "ready" if db_ok else "not ready",
        "checks": {
            "api":      "ok",
            "database": "ok" if db_ok else "unreachable"
        }
    }), status_code


# 3. Get all appointments — with optional filters
@app.route('/appointments', methods=['GET'])
def get_appointments():
    department = request.args.get('department')
    status     = request.args.get('status')

    try:
        conn  = get_db()
        cur   = conn.cursor(cursor_factory=RealDictCursor)

        # Build query dynamically based on filters
        query  = "SELECT * FROM appointments WHERE 1=1"
        params = []

        if department:
            query  += " AND LOWER(department) = LOWER(%s)"
            params.append(department)
        if status:
            query  += " AND LOWER(status) = LOWER(%s)"
            params.append(status)

        query += " ORDER BY created_at DESC;"

        cur.execute(query, params)
        rows = cur.fetchall()
        conn.close()

        return jsonify({
            "count":        len(rows),
            "appointments": [dict(row) for row in rows]
        }), 200

    except Exception as e:
        return jsonify({"error": "Database error", "detail": str(e)}), 500


# 4. Get single appointment by ID
@app.route('/appointments/<appointment_id>', methods=['GET'])
def get_appointment(appointment_id):
    try:
        conn = get_db()
        cur  = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM appointments WHERE id = %s;", (appointment_id,))
        row  = cur.fetchone()
        conn.close()

        if not row:
            return jsonify({"error": "Appointment not found"}), 404

        return jsonify(dict(row)), 200

    except Exception as e:
        return jsonify({"error": "Database error", "detail": str(e)}), 500


# 5. Create a new appointment
@app.route('/appointments', methods=['POST'])
def create_appointment():
    data = request.get_json()

    required = ['patient_name', 'doctor', 'department', 'date', 'time']
    missing  = [f for f in required if f not in data]
    if missing:
        return jsonify({
            "error":   "Missing required fields",
            "missing": missing
        }), 400

    new_id = str(uuid.uuid4())[:8]

    try:
        conn = get_db()
        cur  = conn.cursor()
        cur.execute("""
            INSERT INTO appointments (id, patient_name, doctor, department, date, time, status)
            VALUES (%s, %s, %s, %s, %s, %s, 'pending');
        """, (
            new_id,
            data['patient_name'],
            data['doctor'],
            data['department'],
            data['date'],
            data['time']
        ))
        conn.commit()
        conn.close()

        APPOINTMENT_COUNT.inc()

        return jsonify({
            "message": "Appointment created successfully",
            "appointment": {
                "id":           new_id,
                "patient_name": data['patient_name'],
                "doctor":       data['doctor'],
                "department":   data['department'],
                "date":         data['date'],
                "time":         data['time'],
                "status":       "pending",
                "created_at":   datetime.datetime.utcnow().isoformat() + "Z"
            }
        }), 201

    except Exception as e:
        return jsonify({"error": "Database error", "detail": str(e)}), 500


# 6. Update appointment status
@app.route('/appointments/<appointment_id>', methods=['PATCH'])
def update_appointment(appointment_id):
    data             = request.get_json()
    allowed_statuses = ['pending', 'confirmed', 'cancelled', 'completed']

    if 'status' not in data:
        return jsonify({"error": "No status provided"}), 400

    if data['status'] not in allowed_statuses:
        return jsonify({
            "error": f"Invalid status. Choose from: {allowed_statuses}"
        }), 400

    try:
        conn = get_db()
        cur  = conn.cursor(cursor_factory=RealDictCursor)

        cur.execute("""
            UPDATE appointments
            SET status = %s
            WHERE id = %s
            RETURNING *;
        """, (data['status'], appointment_id))

        updated = cur.fetchone()
        conn.commit()
        conn.close()

        if not updated:
            return jsonify({"error": "Appointment not found"}), 404

        return jsonify({
            "message":     "Appointment updated",
            "appointment": dict(updated)
        }), 200

    except Exception as e:
        return jsonify({"error": "Database error", "detail": str(e)}), 500


# 7. Delete appointment
@app.route('/appointments/<appointment_id>', methods=['DELETE'])
def delete_appointment(appointment_id):
    try:
        conn = get_db()
        cur  = conn.cursor()

        cur.execute(
            "DELETE FROM appointments WHERE id = %s RETURNING id;",
            (appointment_id,)
        )
        deleted = cur.fetchone()
        conn.commit()
        conn.close()

        if not deleted:
            return jsonify({"error": "Appointment not found"}), 404

        return jsonify({
            "message": f"Appointment {appointment_id} deleted"
        }), 200

    except Exception as e:
        return jsonify({"error": "Database error", "detail": str(e)}), 500


# 8. Prometheus metrics — Prometheus scrapes this in Week 6
@app.route('/metrics', methods=['GET'])
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}


# ── Error handlers ────────────────────────────────────────────────────────────
@app.errorhandler(404)
def not_found(e):
    return jsonify({"error": "Route not found"}), 404

@app.errorhandler(500)
def server_error(e):
    return jsonify({"error": "Internal server error"}), 500


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == '__main__':
    print("🚑 ResQOps API starting on port 5000...")
    print(f"📦 DB Host: {DB_HOST} | DB Name: {DB_NAME} | Region: {APP_REGION}")

    # Try to init DB on startup — if it fails, app still starts
    # (Kubernetes will mark it not-ready via /ready until DB is up)
    try:
        init_db()
    except Exception as e:
        print(f"⚠️  DB init failed (will retry via /ready probe): {e}")

    app.run(host='0.0.0.0', port=5000, debug=False)