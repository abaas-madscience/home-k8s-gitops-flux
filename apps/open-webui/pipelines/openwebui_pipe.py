"""
title: N8N RAG Workflow Integration
author: Open WebUI
description: Pipeline that utilizes N8N for RAG workflow processing
version: 1.0.0
"""

import requests
import json
from datetime import datetime
from typing import Dict, Any
from pydantic import BaseModel


class Pipeline:
    """N8N RAG Workflow Pipeline for Open WebUI"""
    
    class Valves(BaseModel):
        """Configuration valves for the N8N pipeline"""
        WEBHOOK_URL: str = "http://n8n.n8n.svc.cluster.local:5678/webhook-test/ragtest"
        TIMEOUT_SECONDS: int = 180
        MAX_CONTEXT_MESSAGES: int = 5
        ENABLE_DEBUG: bool = True
        BEARER_TOKEN: str = ""  # Optional bearer token for authentication

    def __init__(self):
        """Initialize the N8N pipeline"""
        self.name = "N8N RAG Workflow Integration"
        self.valves = self.Valves()

    async def on_startup(self):
        """Called when the pipeline starts"""
        print(f"N8N RAG Pipeline started. Webhook: {self.valves.WEBHOOK_URL}")

    async def on_shutdown(self):
        """Called when the pipeline shuts down"""
        print("N8N RAG Pipeline shutting down...")

    def pipe(
        self, user_message: str, model_id: str, messages: list, body: Dict[str, Any]
    ) -> str:
        """Main pipeline function that processes requests"""
        try:
            # Get user info
            user_id = body.get("user", {}).get("id", "anonymous")
            user_name = body.get("user", {}).get("name", "Unknown")
            
            # Prepare payload for N8N
            payload = {
                "query": user_message,
                "chatInput": user_message,  # Alternative field name
                "model_id": model_id,
                "user_id": user_id,
                "user_name": user_name,
                "timestamp": datetime.now().isoformat(),
                "sessionId": f"openwebui_{user_id}_{int(datetime.now().timestamp())}",
                "messages": messages[-self.valves.MAX_CONTEXT_MESSAGES:] if len(messages) > self.valves.MAX_CONTEXT_MESSAGES else messages
            }
            
            if self.valves.ENABLE_DEBUG:
                print(f"N8N RAG Pipeline: Sending payload: {json.dumps(payload, indent=2)}")
            
            # Prepare headers
            headers = {"Content-Type": "application/json"}
            if self.valves.BEARER_TOKEN and self.valves.BEARER_TOKEN.strip():
                headers["Authorization"] = f"Bearer {self.valves.BEARER_TOKEN}"
            
            # Call N8N webhook
            response = requests.post(
                self.valves.WEBHOOK_URL,
                json=payload,
                timeout=self.valves.TIMEOUT_SECONDS,
                headers=headers
            )
            
            if response.status_code == 200:
                result = response.json()
                
                if self.valves.ENABLE_DEBUG:
                    print(f"N8N RAG Pipeline: Raw response type: {type(result)}")
                    print(f"N8N RAG Pipeline: Raw response: {result}")
                
                # Parse the N8N response
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
            return "Could not connect to N8N service. Check if n8n is running and the webhook URL is correct."
        except Exception as e:
            error_msg = f"N8N RAG Pipeline error: {str(e)}"
            if self.valves.ENABLE_DEBUG:
                import traceback
                error_msg += f"\nTraceback: {traceback.format_exc()}"
            return error_msg
    
    def _parse_n8n_response(self, result):
        """Parse different N8N response formats"""
        try:
            # Case 1: Result is a dictionary
            if isinstance(result, dict):
                return self._format_dict_response(result)
            
            # Case 2: Result is a list (common in N8N)
            elif isinstance(result, list):
                if len(result) == 0:
                    return "No response from N8N workflow"
                
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
            return f"Error parsing N8N response: {str(e)} - Raw response: {result}"
    
    def _format_dict_response(self, data):
        """Format a dictionary response from N8N"""
        # Look for common response fields (in order of preference)
        response_text = (
            data.get("output") or          # Our expected field
            data.get("response") or 
            data.get("message") or 
            data.get("text") or 
            data.get("content") or 
            data.get("answer") or
            data.get("result") or
            "N8N workflow completed"
        )
        
        # Add sources if available
        sources = data.get("sources", [])
        if sources:
            response_text += "\n\n**Sources:**"
            for i, source in enumerate(sources[:3], 1):
                if isinstance(source, dict):
                    source_text = source.get('content', source.get('text', source.get('title', str(source))))
                else:
                    source_text = str(source)
                response_text += f"\n{i}. {source_text[:150]}{'...' if len(source_text) > 150 else ''}"
        
        # Add confidence if available
        confidence = data.get("confidence")
        if confidence is not None:
            response_text += f"\n\n*Confidence: {confidence:.1%}*"
        
        # Add metadata if available
        metadata = data.get("metadata")
        if metadata and isinstance(metadata, dict):
            response_text += f"\n\n*Processing time: {metadata.get('processing_time', 'N/A')}*"
        
        return response_text