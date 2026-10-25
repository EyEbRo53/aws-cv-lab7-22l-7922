import base64
import json
import logging
import os
import time
from urllib.parse import unquote
import boto3

s3 = boto3.client('s3')
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    start = time.monotonic()
    path = unquote(event.get('rawPath') or event.get('path') or '/')
    # Function URLs normally forward the path as-is.
    name = os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'unknown')
    status = 200
    try:
        routes = {'/': ('index.html', 'text/html; charset=utf-8'),
                  '/index.html': ('index.html', 'text/html; charset=utf-8'),
                  '/style.css': ('style.css', 'text/css; charset=utf-8'),
                  '/cv.pdf': ('cv.pdf', 'application/pdf')}
        if path not in routes:
            status = 404
            response = {'statusCode': 404, 'headers': {'Content-Type': 'text/html; charset=utf-8'},
                        'body': '<h1>404 Not Found</h1>'}
        else:
            key, content_type = routes[path]
            data = s3.get_object(Bucket=os.environ['BUCKET'], Key=os.environ['PREFIX'].rstrip('/') + '/' + key)['Body'].read()
            headers = {'Content-Type': content_type}
            if key == 'index.html':
                data = data.decode('utf-8').replace('{{HOSTED_ON}}', 'Lambda ' + name).encode('utf-8')
                headers['Cache-Control'] = 'max-age=60'
            binary = key == 'cv.pdf'
            response = {'statusCode': 200, 'headers': headers, 'isBase64Encoded': binary,
                        'body': base64.b64encode(data).decode('ascii') if binary else data.decode('utf-8')}
    except Exception:
        status = 500
        response = {'statusCode': 500, 'headers': {'Content-Type': 'text/html; charset=utf-8'},
                    'body': '<h1>Internal Server Error</h1>'}
    finally:
        logger.info(json.dumps({'fn': name, 'path': path, 'status': status,
                                'ms': round((time.monotonic() - start) * 1000, 2)}))
    return response
