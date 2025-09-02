"""
title: Simple N8N Test
author: Your Name  
version: 1.0.0
"""

import requests
from pydantic import BaseModel

class Pipeline:
    class Valves(BaseModel):
        webhook_url: str = "http://n8n.n8n.svc.cluster.local:5678/webhook/chat-workflow"
    
    def __init__(self):
        self.name = "Simple N8N Test"
        self.valves = self.Valves()
    
    def pipe(self, user_message: str, model_id: str, messages: list, body: dict) -> str:
        try:
            payload = {"query": user_message, "user_id": "test"}
            response = requests.post(self.valves.webhook_url, json=payload, timeout=10)
            
            if response.status_code == 200:
                return f"✅ N8N Response: {response.json()}"
            else:
                return f"❌ N8N Error: {response.status_code}"
        except Exception as e:
            return f"❌ Error: {str(e)}"
