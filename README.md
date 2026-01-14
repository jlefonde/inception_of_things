# inception-of-things

A comprehensive exploration of Kubernetes orchestration using K3s and K3d. This project progresses from basic multi-node cluster setup using virtualization to advanced GitOps workflows with Argo CD and self-hosted GitLab.

This project follows the 42 School curriculum and is divided into three mandatory parts and one complex bonus.

## ✨ Features

* **Infrastructure as Code (IaC)**: Automating cluster creation using Vagrant, Shell and Ansible provisionning.
* **Multi-Node Clusters**: Implementing a Controller-Agent (Master/Worker) architecture in Part 1.
* **Ingress Routing**: Managing traffic for three applications based on Host headers (`app1.com`, `app2.com`) with a default fallback to App 3.
* **GitOps Continuous Delivery**: Automating deployments with Argo CD to synchronize cluster state with a dedicated configuration repository.
* **Separation of Concerns**: Uses two repositories—one for the setup logic and another (inception_of_things_conf) strictly for K8s manifests.
* **Private Cloud (Bonus)**: Self-hosting a complete GitLab instance within the cluster via Helm.

## 🏗️ Project Structure

The project is organized into four distinct stages:

### [P1] K3s & Vagrant

* **Goal**: Setup 2 Virtual Machines using Vagrant.
* **Nodes**: One master node and one worker node.
* **Specs**: Minimal footprint (1 CPU, 512MB-1024MB RAM).
* **Network**: Static IPs (`192.168.56.110` and `...111`).

### [P2] K3s & Application Ingress

* **Goal**: Deploy three web applications on a single K3s node.
* **Routing**:
   * `Host: app1.com` → App 1.
   * `Host: app2.com` → App 2 (configured with 3 replicas).
   * No Host/Default → App 3.

### [P3] K3d & Argo CD

* **Goal**: Transition to Docker-based K8s (K3d) and implement Argo CD.
* **Workflow**: Argo CD monitors the configuration repository and automatically triggers rolling updates when changes are detected.
* **Namespaces**: Uses `argocd` for the controller and `dev` for the applications.

### [Bonus] GitLab & Helm

* **Goal**: Replace GitHub with a local GitLab instance.
* **Deployment**: Installed in a `gitlab` namespace using Helm.
* **Integration**: Argo CD is configured to pull manifests from the local GitLab instead of GitHub.

## 🔄 GitOps Workflow

* **Manifest Repository**: Contains `deployment.yaml` and `service.yaml`.
* **Sync Process**: When pushing a change to the `-conf` repo (e.g., updating the image tag from `v1` to `v2`), Argo CD detects the difference and updates the cluster automatically.
