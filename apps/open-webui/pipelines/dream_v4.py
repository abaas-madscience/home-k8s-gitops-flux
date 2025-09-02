"""
title: N8N Workflow Integration
author: Your Name
version: 1.0.0
"""

import requests
import json
from datetime import datetime
from typing import Dict, Any
from pydantic import BaseModel

class Pipeline:
    class Valves(BaseModel):
        WEBHOOK_URL: str = "http://n8n.n8n.svc.cluster.local:5678/webhook-test/dream-workflow"
        TIMEOUT_SECONDS: int = 30
        MAX_CONTEXT_MESSAGES: int = 3
        ENABLE_DEBUG: bool = True  # Enable debug to see what's coming back

    def __init__(self):
        self.name = "N8N Workflow Integration"
        self.valves = self.Valves()

    async def on_startup(self):
        print(f"N8N Pipeline started. Webhook: {self.valves.WEBHOOK_URL}")

    async def on_shutdown(self):
        print("N8N Pipeline shutting down...")

    def pipe(
        self, user_message: str, model_id: str, messages: list, body: Dict[str, Any]
    ) -> str:
        try:
            # Get user info
            user_id = body.get("user", {}).get("id", "anonymous")
            user_name = body.get("user", {}).get("name", "Unknown")
            
            # Prepare payload
            payload = {
                "query": user_message,
                "model_id": model_id,
                "user_id": user_id,
                "user_name": user_name,
                "timestamp": datetime.now().isoformat(),
                "messages": messages[-self.valves.MAX_CONTEXT_MESSAGES:] if len(messages) > self.valves.MAX_CONTEXT_MESSAGES else messages
            }
            
            if self.valves.ENABLE_DEBUG:
                print(f"N8N Pipeline: Sending payload: {json.dumps(payload, indent=2)}")
            
            # Call N8N webhook
            response = requests.post(
                self.valves.WEBHOOK_URL,
                json=payload,
                timeout=self.valves.TIMEOUT_SECONDS,
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code == 200:
                result = response.json()
                
                if self.valves.ENABLE_DEBUG:
                    print(f"N8N Pipeline: Raw response type: {type(result)}")
                    print(f"N8N Pipeline: Raw response: {result}")
                
                # Handle different response formats from n8n
                workflow_response = self._parse_n8n_response(result)
                
                return workflow_response
            
            else:
                error_msg = f"N8N workflow failed (Status: {response.status_code})"
                if self.valves.ENABLE_DEBUG:
                    error_msg += f"\nResponse: {response.text}"
                return error_msg
                
        except requests.exceptions.Timeout:
            return f"N8N workflow timed out after {self.valves.TIMEOUT_SECONDS} seconds"
        except requests.exceptions.ConnectionError:
            return "Could not connect to N8N service. Check if n8n is running."
        except Exception as e:
            error_msg = f"N8N Pipeline error: {str(e)}"
            if self.valves.ENABLE_DEBUG:
                import traceback
                error_msg += f"\nTraceback: {traceback.format_exc()}"
            return error_msg
    
    def _parse_n8n_response(self, result):
        """Parse different n8n response formats"""
        try:
            # Case 1: Result is a dictionary
            if isinstance(result, dict):
                return self._format_dict_response(result)
            
            # Case 2: Result is a list (common in n8n)
            elif isinstance(result, list):
                if len(result) == 0:
                    return "No response from workflow"
                
                # Take the first item if it's a list
                first_item = result[0]
                
                if isinstance(first_item, dict):
                    return self._format_dict_response(first_item)
                else:
                    return str(first_item)
            
            # Case 3: Result is a string or other type
            else:
                return str(result)
                
        except Exception as e:
            return f"Error parsing n8n response: {str(e)} - Raw response: {result}"
    
    def _format_dict_response(self, data):
        """Format a dictionary response from n8n"""
        # Look for common response fields
        response_text = (
            data.get("response") or 
            data.get("message") or 
            data.get("text") or 
            data.get("content") or 
            data.get("output") or
            "Workflow completed"
        )
        
        # Add sources if available
        sources = data.get("sources", [])
        if sources:
            response_text += "\n\n**Sources:**"
            for i, source in enumerate(sources[:3], 1):
                if isinstance(source, dict):
                    source_text = source.get('content', source.get('text', str(source)))
                else:
                    source_text = str(source)
                response_text += f"\n{i}. {source_text[:100]}{'...' if len(source_text) > 100 else ''}"
        
        # Add confidence if available
        confidence = data.get("confidence")
        if confidence is not None:
            response_text += f"\n\n*Confidence: {confidence:.1%}*"
        
        return response_text
