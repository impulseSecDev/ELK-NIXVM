{config, pkgs, lib, ... }:

{

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      elasticsearch = {
        image = "docker.elastic.co/elasticsearch/elasticsearch:8.13.0";
        environmentFiles = [ /etc/secrets/elastic.env ];
	volumes = [ "/var/lib/elasticsearch:/usr/share/elasticsearch/data" ];
        environment = {
          "discovery.type" = "single-node";
          "xpack.security.enabled" = "true";
          "network.host" = "[\"127.0.0.1\", \"10.10.10.2\", \"100.64.0.3\"]";
	  "cluster.name" = "playbox";
        };
        extraOptions = [ "--network=host" ];
      };
      kibana = {
        image = "docker.elastic.co/kibana/kibana:8.13.0";
        environmentFiles = [ /etc/secrets/elastic.env ];
        environment = {
          "ELASTICSEARCH_HOSTS" = "http://127.0.0.1:9200";
          "SERVER_HOST" = "127.0.0.1";
	  "XPACK_SECURITY_ENABLED" = "true";
	   "SERVER_PUBLICBASEURL" = "https://elkbox.mesh.loranjennings.com";
        };
        extraOptions = [ "--network=host" ];
      };
    };
  };
}
