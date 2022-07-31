# Node.js

The [Lagoon `node` Docker image](https://github.com/uselagoon/lagoon-images/tree/main/images/node). Based on [the official Node Alpine images](https://hub.docker.com/_/node/).

## Supported Versions

We ship 2 versions of Node.js images: the normal `node:version` image and the `node:version-builder`.

The builder variant of those images comes with additional tooling that is needed when you build Node.js apps (such as the build libraries, npm and yarn). For a full list check out their [Dockerfile](https://github.com/uselagoon/lagoon-images/tree/main/images/node-builder).


* 12 \(available for compatibility, no longer officially supported\) - `uselagoon/node-12`
* 14 [Dockerfile](https://github.com/uselagoon/lagoon-images/blob/main/images/node/14.Dockerfile) (Security Support until 30 April 2023) - `uselagoon/node-14`
* 16 [Dockerfile](https://github.com/uselagoon/lagoon-images/blob/main/images/node/16.Dockerfile) (Security Support until 11 September 2023) - `uselagoon/node-16`
* 18 [Dockerfile](https://github.com/uselagoon/lagoon-images/blob/main/images/node/18.Dockerfile) (Security Support until 30 April 2025) - `uselagoon/node-18`

!!! Note "Note:"
    We stop updating EOL Node.js images usually with the Lagoon release that comes after the officially communicated EOL date: [https://nodejs.org/en/about/releases/](https://nodejs.org/en/about/releases/).

## Lagoon adaptions

The default exposed port of node containers is port `3000`.

Persistent storage is configurable in Lagoon, using the `lagoon.type: node-persistent`. See [the docs](../using-lagoon-the-basics/docker-compose-yml.md#persistent-storage) for more info

Use the following labels in your docker-compose.yml file to configure it:
`lagoon.persistent` = use this to define the path in the container to use as persistent storage - e.g. /app/files
`lagoon.persistent.size` = this to tell Lagoon how much storage to assign this path

If you have multiple services that share the same storage, use this
`lagoon.persistent.name` = (optional) use this to tell Lagoon to use the storage defined in another named service

## docker-compose.yml snippet

    ```yaml title="docker-compose.yml snippet"
		node:
            build:
                # this configures a build from a Dockerfile in the root folder
                context: .
                dockerfile: Dockerfile
            labels:
				# tells Lagoon this is a node service, configured with 500MB of persistent storage at /app/files
                lagoon.type: node-persistent
                lagoon.persistent: /app/files
                lagoon.persistent.size: 500Mi
            ports:
				# local development only
                # this exposes the port 3000 with a random local port - find it with docker-compose port node 3000
				- "3000"
			volumes:
				# local development only
				# mounts a named volume (files) at the defined path for this service to replicate production
				- files:/app/files
    ```

## Environment Variables

Environment variables are meant to contain common information for the PHP container.

| Environment Variable | Default | Description |
| :--- | :--- | :--- |
| `LAGOON_LOCALDEV_HTTP_PORT` | 3000 | tells the local development environment on which port we are running |
