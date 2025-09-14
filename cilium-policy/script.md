### Demo Steps

1. New terminal tab 1: Start kagent dashboard.
```bash
kagent 
dashboard
```

2. Apply the application yaml.
```bash
kubectl apply -f application.yaml
```

3. New terminal tab 2: Start hubble UI.
```bash
cilium hubble port-forward&
cilium hubble ui
```

4. Observe normal hubble flows, then apply policy. Observe hubble flows afterwards (dropped flows).
```bash
kubectl apply -f broken-policy.yaml
```

4. Create the Cilium policy agent by applying the yaml via CLI or using the UI.

CLI: 
```bash
kubectl apply -f cilium-policy-agent.yaml
```

UI:
Use `prompt-cilium-policy-agent.md` as the system prompt for the agent.

5. Chat with the cilium policy agent in the Kagent dashboard, ask:

I have a new cilium policy called 'broken-backend-policy' I added in the default ns to restrict connection such that only the frontend can reach the backend pods, but now the connection is broken! Can you help fix it?

6. Prompt the agent to patch the policy to fix it, once it recognises the issue.
