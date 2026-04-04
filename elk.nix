{config, pkgs, lib, ... }:

{

  sops.secrets = {
    "elasticsearch_username" = {};
    "elasticsearch_password" = {};
    "elastic_user" = {};
    "elastic_password" = {};
    "xpack_encryptedsavedobjects_encryptionkey" = {};
    "xpack_reporting_encryptionkey" = {};
    "xpack_security_encryptionkey" = {};
  };

  sops.templates."elastic.env" = {
    content = ''
      ELASTICSEARCH_USERNAME=${config.sops.placeholder."elasticsearch_username"}
      ELASTICSEARCH_PASSWORD=${config.sops.placeholder."elasticsearch_password"}
      ELASTIC_USERNAME=${config.sops.placeholder."elastic_user"}
      ELASTICPASSWORD=${config.sops.placeholder."elastic_password"}
      XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY=${config.sops.placeholder."xpack_encryptedsavedobjects_encryptionkey"}
      XPACK_REPORTING_ENCRYPTIONKEY=${config.sops.placeholder."xpack_reporting_encryptionkey"}
      XPACK_SECURITY_ENCRYPTIONKEY=${config.sops.placeholder."xpack_security_encryptionkey"}
   '';
   path = "/run/secrets/elastic.env";
   mode = "0440";
   owner = "root";
   group = "root";
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      elasticsearch = {
        image = "docker.elastic.co/elasticsearch/elasticsearch:9.3.2";
        environmentFiles = [ config.sops.templates."elastic.env".path ];
	volumes = [ "/var/lib/elasticsearch:/usr/share/elasticsearch/data" ];
        environment = {
          "discovery.type" = "single-node";
          "xpack.security.enabled" = "true";
          "network.host" = "[ \"127.0.0.1\", \"10.10.10.2\" ]";
	  "cluster.name" = "playbox";
        };
        extraOptions = [ "--network=host" ];
      };
      kibana = {
        image = "docker.elastic.co/kibana/kibana:9.3.2";
        environmentFiles = [ config.sops.templates."elastic.env".path ];
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
