"""
title: N8N Workflow Integration
author: Your Name
version: 1.0.0
"""

import requests
import json
from datetime import datetime
from typing import Dict, Any

class Pipeline:
    def __init__(self):
        self.name = "n8n_workflow"
        self.n8n_webhook_url = "http://n8n.n8n.svc.cluster.local:5678/webhook/dream-workflow"
    
    async def on_startup(self):
        print(f"N8N Pipeline: Webhook URL: {self.n8n_webhook_url}")
    
    async def on_shutdown(self):
        pass
    
    def pipe(
        self, user_message: str, model_id: str, messages: list, body: Dict[str, Any]
    ) -> str:
        try:
            payload = {
                "query": user_message,
                "model_id": model_id,
                "user_id": body.get("user", {}).get("id", "anonymous"),
                "timestamp": datetime.now().isoformat(),
                "messages": messages[-3:] if len(messages) > 3 else messages
            }
            
            response = requests.post(
                self.n8n_webhook_url,
                json=payload,
                timeout=30,
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code == 200:
                result = response.json()
                return result.get("response", "Workflow completed")
            else:
                return f"Workflow failed: {response.status_code}"
                
        except Exception as e:
            return f"Error calling workflow: {str(e)}"
