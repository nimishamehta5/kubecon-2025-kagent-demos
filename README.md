# kubecon-2025-kagent-demos

### Prerequisites
* [Kubectl](https://kubernetes.io/docs/tasks/tools/) installed locally.
* [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/) installed locally.
* [Helm](https://helm.sh/docs/intro/install/) installed locally.
* The [Cilium CLI](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli) installed.
* [Hubble CLI](https://docs.cilium.io/en/stable/observability/hubble/setup/index.html#install-the-hubble-client) installed.
* [Kagent CLI](https://kagent.dev/docs/kagent/getting-started/quickstart#installing-kagent) installed locally.
* An [OpenAI API key](https://platform.openai.com/api-keys), set as an environment variable `OPENAI_API_KEY`.
* A [GitHub Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token), set as an environment variable `GITHUB_PERSONAL_ACCESS_TOKEN`.

Note: This demo uses Kagent version 0.6.19.

### Setup

```bash
cd setup
./setup.sh
```

For each demo, cd into the demo directory and follow specific instructions in the README / script there.
