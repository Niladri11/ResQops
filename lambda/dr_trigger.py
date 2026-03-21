import boto3
import json
import os
import subprocess
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    logger.info(f"DR trigger received: {json.dumps(event)}")
    
    # Parse SNS message from AlertManager
    message = json.loads(event['Records'][0]['Sns']['Message'])
    alerts = message.get('alerts', [])
    
    for alert in alerts:
        alert_name = alert.get('labels', {}).get('alertname', '')
        status = alert.get('status', '')
        
        logger.info(f"Alert: {alert_name}, Status: {status}")
        
        if alert_name == 'AppDown' and status == 'firing':
            logger.info("Primary region DOWN — triggering DR deployment")
            trigger_dr()
            return {
                'statusCode': 200,
                'body': 'DR triggered successfully'
            }
    
    return {
        'statusCode': 200,
        'body': 'No DR action needed'
    }

def trigger_dr():
    # Notify Slack that DR is starting
    import urllib.request
    
    slack_url = os.environ.get('SLACK_WEBHOOK_URL')
    message = {
        "text": "🚨 *DR INITIATED* — Primary region down. Spinning up DR infrastructure in ap-southeast-1..."
    }
    
    req = urllib.request.Request(
        slack_url,
        data=json.dumps(message).encode(),
        headers={'Content-Type': 'application/json'}
    )
    urllib.request.urlopen(req)
    
    # Trigger GitHub Actions DR workflow via repository dispatch
    github_token = os.environ.get('GITHUB_TOKEN')
    github_repo = os.environ.get('GITHUB_REPO')
    
    dispatch_url = f"https://api.github.com/repos/{github_repo}/dispatches"
    payload = {
        "event_type": "dr-trigger",
        "client_payload": {
            "reason": "primary-region-down"
        }
    }
    
    req = urllib.request.Request(
        dispatch_url,
        data=json.dumps(payload).encode(),
        headers={
            'Authorization': f'token {github_token}',
            'Accept': 'application/vnd.github.v3+json',
            'Content-Type': 'application/json'
        }
    )
    urllib.request.urlopen(req)
    logger.info("GitHub Actions DR workflow triggered")