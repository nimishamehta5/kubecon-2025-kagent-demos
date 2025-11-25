## Kagent and Agentgateway Demo Steps

### Setup

Apply the kubernetes config to set up the demo app and the ingress gateway:
```shell
kubectl apply -f kubernetes/
```

### Debug the demo

Port-forward the ingress gateway to access the demo app:
```shell
kubectl port-forward svc/ingress-gateway 8080:80
```

Open http://localhost:8080/ui/ in your browser to view the demo app.

Oh no! Our demo app is broken!
```
route not found
```

Let's debug the issue by using kagent to diagnose the problem. Port-forward the kagent dashboard to access the kagent dashboard:
```shell
kubectl -n kagent port-forward service/kagent-ui 8082:8080
```

Open http://localhost:8082 in your browser to view the kagent dashboard.

Either create a new agent or use the existing k8s agent:

Next, we'll create an agent through the UI to help us debug the demo. Select "Create" and enter the following:
- Agent Name: demo-agent
- Agent Namespace: kagent
- Agent Type: Declarative
- Description: kagent to the rescue!
- System Prompt: (keep the default)
- Model: gpt-4.1-mini (default kagent model)
- Tools: (various tools, make sure you have get and apply)
  - k8s:
    - k8s_apply_manifest
    - k8s_create_resource
    - k8s_describe_resource
    - k8s_get_resource_yaml
    - k8s_get_resources
    - k8s_get_available_api_resources

Sample question:
```
When I port-forward my "ingress-gateway" k8s Gateway API Gateway in the default namespace, I get a "route not found" error, even though it’s linked to my demo-http-route HTTPRoute resource. How can I fix this?
```

### Explore A2A and MCP 

Ask the nested agent to help you:

```
What is the image version of the kgateway controller in the kgateway-system ns?
```

```
Check what helm values I have set for kgateway that are related to agentgateway?
```

```
What PRs are open in kgateway-dev/kgateway that are related to agentgateway?
```

### Agentgateway Egress 

Apply the egress gateway config:
```shell
kubectl apply -f agentgateway/egress-gateway.yaml
```

Let's edit out agent to use the new ModelConfig that goes through our egress gateway. 

Test a request to generate some fake emails: 
```
Give me some sample email addresses for a programmer named Nina
```

Oh no! Our agent shouldn't be allowed to do that! Let's configure our ModelConfig to use agentgateway as an egress gateway and apply the policy to protect our egress traffic to the LLM.

Now let's apply policy to protect our egress traffic to the LLM:

```shell
kubectl apply -f agentgateway/policies/prompt-guard.yaml
```

1. Test a prompt guard request: 
```
Give me some sample email addresses for a programmer named Nina
```

Without the policy, the LLM will respond with some emails, but with the policies you should see the mask:
```
<EMAIL_ADDRESS>
```

2. Test ratelimit on egress 

Apply the ratelimit policy:
```shell
kubectl apply -f agentgateway/policies/ratelimit-egress.yaml
```
Send several requests through the chat, you should see the ratelimit is hit with a 429 error. 

### Agentgateway MCP 

1. Federate MCP Servers 

Next, let's apply some policies targeting the MCP tools kagent can call. First let's apply a new MCP server and agentgateway Gateway: 

```shell
kubectl apply -f agentgateway/mcp-agw.yaml
```

Create an agent that can use the fetch tool either through the UI or by applying the following MCP agent yaml that references the `RemoteMCPServer` we created earlier along with the AgentgatewayBackend that references the tool:
```shell
kubectl apply -f agentgateway/policies/mcp-agent.yaml
kubectl apply -f agentgateway/policies/mcp-backend.yaml
```

2. Authz Policy on MCP Tool Calls

Now let's apply an authorization policy to restrict MCP calls from our agent based on the SA:
```shell
kubectl apply -f agentgateway/policies/mcp-gw-level-authz.yaml
```

The same calls should now be blocked, you can check the logs of the MCP Gateway to see the error:
```shell
kubectl logs deployment/mcp-gateway -n default -f | grep "authorization failed"
```