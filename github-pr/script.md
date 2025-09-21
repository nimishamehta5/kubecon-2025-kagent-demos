### Demo Steps

1. Port-forward argocd server and visit http://localhost:8080.
```bash
kubectl port-forward service/argocd-server -n argocd 8080:443
```

2. Port forward the frontend service and view healthy application.
```bash
kubectl port-forward svc/frontend 9090:9090
```
Open http://localhost:9090/ui/.

3. Break the environment.
```bash
./break.sh
```

4. The sample-app repo should now show the broken commit: https://github.com/nimishamehta5/sample-app

5. Go to Argo UI, sync the application. The frontend will show the application as unhealthy.

6. Apply the gitops agent.
```bash
kubectl apply -f github-fix-agent.yaml
```

7. Start kagent dashboard, navigate to gitops agent.
```
kagent dashboard
```

8. Ask the agent to fix the environment.

Prompts:
"Calling the frontend service at http://frontend:9090 I see HTTP 500 errors. The apps are running in the default namespace."

Follow-up prompt:
"GH repo name: https://github.com/nimishamehta5/sample-app
Create the branch from main. 
You can call it "fix-live-demo-branch"
The services are in the application.yaml file, can you check the GH repo?"

9. Kagent should open a PR in the repo to fix the incorrect config.

### Curl the frontend service
```bash
kubectl run curl-test --image=curlimages/curl -it --rm -- sh
curl http://frontend:9090
```

### Argo UI

In order to access the server UI you have the following options:

1. kubectl port-forward service/argocd-server -n argocd 8080:443

    and then open the browser on http://localhost:8080 and accept the certificate

2. enable ingress in the values file `server.ingress.enabled` and either
      - Add the annotation for ssl passthrough: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#option-1-ssl-passthrough
      - Set the `configs.params."server.insecure"` in the values file and terminate SSL at your ingress: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#option-2-multiple-ingress-objects-and-hosts


After reaching the UI the first time you can login with username: admin and the random password generated during the installation. You can find the password by running:

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

(You should delete the initial secret afterwards as suggested by the Getting Started Guide: https://argo-cd.readthedocs.io/en/stable/getting_started/#4-login-using-the-cli)
