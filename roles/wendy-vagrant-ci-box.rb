name "wendy-vagrant-ci-box"
description "Box-specific parameters for Wendy project testbox"

default_attributes(
	"postgresql" => {
		"password" => {
			"postgres" => "b497dd1a701a33026f7211533620780d" # drowssap
		},
		"pg_hba" => [
			{
				"type" => "local",
				"db" => "all",
				"user" => "all",
				"addr" => nil,
				"method" => "trust"
			},
			{
				"type" => "host",
				"db" => "all",
				"user" => "all",
				"addr" => "127.0.0.1/32",
				"method" => "trust"
			}
		]
	}
)

