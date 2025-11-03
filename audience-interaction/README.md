# Debugging Demo

Our live demo has hit a snag, can kagent save the day?

This demo is based on Lin Sun's [gen-ai-demo](https://github.com/linsun/gen-ai-demo), but some of the config is not correct.
Let's use kagent to debug our cluster and get the demo working!

# Setup 

The Gen AI Demo uses Kubernetes, Istio Ambient, Prometheus, Kiali

## Prerequisites

- A Kubernetes cluster, for example a [kind](https://kind.sigs.k8s.io/) cluster (if you do not have one, the setup script will set up a kind cluster named "kind")
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [kagent](https://kagent.dev/docs/kagent/getting-started/quickstart) CLI 

## Startup

We have crafted a few scripts to make this demo run as quickly as possible on your machine once you've installed the prerequisites.

This script will:

- Create a kind cluster
- Install a simple curl client, an [ollama](https://ollama.com/) service and the demo service.
  - Ollama is a Language Model as a Service (LMaaS) that provides a RESTful API for interacting with large language models. It's a great way to get started with LLMs without having to worry about the infrastructure.

```sh
./startup.sh
```

Apply the Gateway and HTTPRoute config to setup the ingress route:
```sh
kubectl apply -f kubernetes/
```

## Pull the LLM models

The following two LLM models are used in the demo:
- LLaVa (Large Language and Vision Assistant)
- Llama (Large Language Model Meta AI) 3.2

Run ollama locally:
```sh
ollama serve
```

Pull the two models:
```sh
ollama pull llava
ollama pull llama3.2
```

## Access the demo app

Use port-forwarding to help us access the demo app:

```sh
kubectl port-forward svc/ingress-gateway 8001:80
```

To access the demo app, open your browser and navigate to [http://localhost:8001](http://localhost:8001)

Oh no! We have an error:
```
route not found
```

How can we fix this? 

# kagent to the rescue!

Chatting with the kubernetes agent, you should be able to get it to patch the HTTPRoute to be in the default ns.

In a new terminal tab, start kagent dashboard.
```sh
kubectl -n kagent port-forward service/kagent-ui 8082:8080
```

Sample question:
```
When I port-forward my "ingress-gateway" in the default namespace, I get a "route not found" error, even though it’s linked to my demo-http-route. How can I fix this?
```

# Multiple agents in action

Next, let's apply the nested agent to the cluster:
```sh
kubectl apply -f a2a/
```

Ask the nested agent to help you:

```
What version of kgateway am I running? 
```

```
Check what helm values I have set for kgateway that are related to agentgateway?
```

```
What PRs are open in kgateway-dev/kgateway that are related to agentgateway?
```

## Cleanup

To clean up the demo, run the following command:
```sh
./cleanup-istio.sh
./shutdown.sh
```

## Operating System Information

This demo has been tested on the following operating systems and will work if you have the prerequisites installed. You may need to build the demo app images yourself if you are on a different platform.

- macOS M2

## Credits
A portion of the demo in this repo was inspired by the [github.com/cncf/llm-in-action](github.com/cncf/llm-in-action) repo and Lin Sun's [gen-ai-demo](https://github.com/linsun/gen-ai-demo).


