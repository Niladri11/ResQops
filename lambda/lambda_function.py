import json
import os
import urllib.request
import urllib.error

def lambda_handler(event, context):
    github_repo = os.environ.get('GITHUB_REPO', 'Niladri11/ResQops')
    github_token = os.environ.get('GITHUB_TOKEN')
    workflow_id = os.environ.get('WORKFLOW_ID', 'dr-trigger.yml')
    
    if not github_token:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'GITHUB_TOKEN not set'})
        }

    url = f"https://api.github.com/repos/{github_repo}/actions/workflows/{workflow_id}/dispatches"
    
    payload = json.dumps({
        "ref": "main",
        "inputs": {
            "reason": "Primary region failure detected by Prometheus AlertManager"
        }
    }).encode('utf-8')

    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            'Authorization': f'token {github_token}',
            'Accept': 'application/vnd.github.v3+json',
            'Content-Type': 'application/json'
        },
        method='POST'
    )

    try:
        with urllib.request.urlopen(req) as response:
            print(f"DR workflow triggered. Status: {response.status}")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'DR workflow triggered successfully',
                    'repo': github_repo,
                    'workflow': workflow_id
                })
            }
    except urllib.error.HTTPError as e:
        error_body = e.read().decode()
        print(f"GitHub API error: {e.code} - {error_body}")
        return {
            'statusCode': e.code,
            'body': json.dumps({'error': error_body})
        }
