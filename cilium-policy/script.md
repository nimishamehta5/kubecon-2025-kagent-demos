### Demo Steps

1. New terminal tab: Start kagent dashboard.
```bash
kubectl -n kagent port-forward service/kagent-ui 8082:8080
```
Open http://localhost:8082

2. New terminal tab: Start hubble UI. Observe normal hubble flows between frontend and backend pods.
```bash
cilium hubble port-forward&
cilium hubble ui
```

3. Apply policy. Observe hubble flows afterwards (dropped flows). The dropped flows take a few seconds to appear.
```bash
kubectl -n default apply -f broken-policy.yaml
```

4. Create the Cilium policy agent by applying the yaml via CLI or using the UI.

CLI: 
```bash
kubectl -n default apply -f cilium-policy-agent.yaml
```

UI:
Use `prompt-cilium-policy-agent.md` as the system prompt for the agent.

Add the following built-in k8s tools + Cilium tools:
```
    tools:
    - mcpServer:
        apiGroup: kagent.dev
        kind: RemoteMCPServer
        name: kagent-tool-server
        toolNames:
        - cilium_display_policy_node_information
        - cilium_validate_cilium_network_policies
      type: McpServer
    - mcpServer:
        apiGroup: kagent.dev
        kind: RemoteMCPServer
        name: kagent-tool-server
        toolNames:
        - k8s_apply_manifest
        - k8s_create_resource
        - k8s_describe_resource
        - k8s_get_resource_yaml
        - k8s_get_resources
        - k8s_patch_resource
        - k8s_get_available_api_resources
```

5. Chat with the cilium policy agent in the Kagent dashboard, ask:

```
I have a new cilium policy called 'restrict-backend-policy' I added in the default ns to restrict connection such that only the frontend can reach the backend pods, but now the connection is broken! Can you help fix the policy?
```

6. Prompt the agent to patch the policy to fix it, once it recognises the issue.
