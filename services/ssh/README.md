<p align="center"><img
src="https://raw.githubusercontent.com/amazeeio/lagoon/main/docs/images/lagoon-logo.png"
alt="The Lagoon logo is a blue hexagon split in two pieces with an L-shaped cut"
width="40%"></p>

This service is part of amazee.io Lagoon, a Docker build and deploy system for
OpenShift & Kubernetes. Please reference our [documentation] for detailed
information on using, developing, and administering Lagoon.

# SSH (`ssh`)

Acts as the main entrypoint for all SSH-related connections and commands for
Lagoon projects. All connections are authenticated via the Lagoon API using
standard SSH public/private keys. Authenticated connections can: 1) request a
token that can be used to authenticate to the Lagoon API or 2) connect via SSH
to a Lagoon project environment.

This service is typically transparent to end users since connections are handled
by Drush for Drupal projects, but direct connections can be made for non-Drush
workflows.

## Technology

* Bash
* Python

## Related Services

* API [***dependency***]
* auth-server [***dependency***]

[documentation]: https://docs.lagoon.sh/
