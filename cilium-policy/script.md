### Demo Steps

1. New terminal tab 1: Start kagent dashboard.
```bash
kagent 
dashboard
```

2. New terminal tab 2: Start hubble UI. Observe normal hubble flows between frontend and backend pods.
```bash
cilium status
cilium hubble port-forward&
cilium hubble ui
```

3. Apply policy. Observe hubble flows afterwards (dropped flows). The dropped flows take about 45 seconds to appear.
```bash
kubectl -n default apply -f broken-policy.yaml
```

4. Create the Cilium policy agent by applying the yaml via CLI or using the UI.

CLI: 
```bash
kubectl -n default apply -f cilium-policy-agent.yaml
kubectl -n default apply -f kagent-cilium-rbac.yaml
```

UI:
Use `prompt-cilium-policy-agent.md` as the system prompt for the agent.

Add the following built-in k8s tools:
```
ApplyManifest
CreateResource
DescribeResource
GetAvailableAPIResources
GetResources
GetResourceYAML
PatchResource
```

5. Chat with the cilium policy agent in the Kagent dashboard, ask:

```
I have a new cilium policy called 'restrict-backend-policy' I added in the default ns to restrict connection such that only the frontend can reach the backend pods, but now the connection is broken! Can you help fix it?
```

6. Prompt the agent to patch the policy to fix it, once it recognises the issue.
