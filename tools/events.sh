#!/bin/bash

# Watch Kubernetes events per namespace
# Usage: ./tools/events.sh [namespace] [options]
# Options:
#   -w, --watch     Watch events in real-time
#   -f, --follow    Follow events (like tail -f)
#   -a, --all       Show all namespaces
#   -n, --normal    Include Normal events (default: exclude)

NAMESPACE=""
WATCH=false
FOLLOW=false
ALL_NS=false
INCLUDE_NORMAL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -w|--watch)
      WATCH=true
      shift
      ;;
    -f|--follow)
      FOLLOW=true
      shift
      ;;
    -a|--all)
      ALL_NS=true
      shift
      ;;
    -n|--normal)
      INCLUDE_NORMAL=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [namespace] [options]"
      echo "Options:"
      echo "  -w, --watch     Watch events in real-time"
      echo "  -f, --follow    Follow events (like tail -f)"
      echo "  -a, --all       Show all namespaces"
      echo "  -n, --normal    Include Normal events (default: exclude)"
      echo ""
      echo "Examples:"
      echo "  $0 n8n                    # Show recent events in n8n namespace"
      echo "  $0 n8n -w                # Watch events in n8n namespace"
      echo "  $0 -a                     # Show events from all namespaces"
      echo "  $0 kube-system -n         # Include Normal events"
      exit 0
      ;;
    *)
      if [[ -z "$NAMESPACE" ]]; then
        NAMESPACE="$1"
      else
        echo "Unknown option: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

# Build kubectl command
CMD="kubectl get events"

if [[ "$ALL_NS" == "true" ]]; then
  CMD="$CMD --all-namespaces"
elif [[ -n "$NAMESPACE" ]]; then
  CMD="$CMD -n $NAMESPACE"
fi

CMD="$CMD --sort-by='.lastTimestamp'"

if [[ "$INCLUDE_NORMAL" == "false" ]]; then
  CMD="$CMD --field-selector type!=Normal"
fi

if [[ "$WATCH" == "true" ]]; then
  CMD="$CMD --watch"
elif [[ "$FOLLOW" == "true" ]]; then
  CMD="$CMD --watch-only"
fi

echo "🔍 Running: $CMD"
echo "📅 $(date)"
echo "---"

# Execute the command
eval $CMD