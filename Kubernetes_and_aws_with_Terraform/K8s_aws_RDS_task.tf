provider "kubernetes" {
    config_context_cluster = "minikube"
}

resource "kubernetes_deployment" "test_kube" {
    metadata {
        name = "wordpressappdeploy1"
    }

    spec {
        replicas = 1

        selector {
            match_labels = {
                env = "dev"
                app = "wordpress"
            }
        }
        
        template {
            metadata {
                labels = {
                    env = "dev"
                    app = "wordpress"
                }
            }

            spec {
                container {
                    image = "wordpress:4.8-apache"
                    name = "wordpressappdeploy1"
                }
            }
        }
    }
}

resource "kubernetes_service" "npwp" {
    metadata {
        name = "npwp1"
    }

    spec {
        selector = {
            env = "dev"
            app = "wordpress"
        }
        port {
            node_port = 30000
            port = 80
            target_port = 80
        }

        type = "NodePort"
    }
}