---
description: Lagoon supports active/standby (also known as blue/green) deployments.
---

# Active/Standby

{% embed url="https://www.youtube.com/watch?v=urq15chLvzQ" caption="How to Run Blue-Green Deployments with Active/Standby on Lagoon" %}

## Configuration

To change an existing project to support active/standby you'll need to configure some project settings with the Lagoon API.

* `productionEnviromment` should be set to the branch name of the current active environment.
* `standbyProductionEnvironment` should be set to the branch name of the current environment that is in standby.

```graphql
mutation updateProject {
  updateProject(input:{
    id:1234
    patch:{
      productionEnvironment:"production-brancha"
      standbyProductionEnvironment:"production-branchb"
    }
  }){
    standbyProductionEnvironment
    name
    productionEnvironment
  }
}
```

### `.lagoon.yml` - `production_routes`

To configure a project for active/standby in the `.lagoon.yml` file, you'll need to configure the `production_routes` section with any routes you want to attach to the `active` environment, and any routes to the `standby` environment. During an active/standby switch, these routes will migrate between the two environments.

If you have two production environments, `production-brancha` and `production-branchb`, with the current active production environment as `production-brancha` then:

* Routes under `production_routes.active` will direct you to `production-brancha`.
* Routes under `production_routes.standby` will direct you to `production-branchb`.

During an active/standby switch, the routes will swap:

* Routes under `production_routes.active` will direct you to `production-branchb`.
* Routes under `production_routes.standby` will direct you to `production-brancha`.

{% tabs %}
{% tab title=".lagoon.yml" %}
```yaml
production_routes:
  active:
    routes:
      - nginx:
        - example.com:
            tls-acme: 'false'
        - active.example.com:
            tls-acme: 'false'
  standby:
    routes:
      - nginx:
        - standby.example.com:
            tls-acme: 'false'
```
{% endtab %}
{% endtabs %}

{% hint style="info" %}
Any routes that are under the section `environments..routes` will not be moved as part of active/standby. These routes will always be attached to the environment as defined. Ensure that if you do need a specific route to be migrated during an active/standby switch, that you remove them from the environments section and place them under the `production_routes` section specific to if it should be an active or standby route. [See more about routes in `.lagoon.yml`.](../using-lagoon-the-basics/lagoon-yml.md#routes)
{% endhint %}

## Triggering a switch event

### via the UI

To trigger the switching of environment routes, you can visit the standby environment in the Lagoon UI and click on the button labeled `Switch Active/Standby environments`. You will be prompted to confirm your action.

Once confirmed, it will take you to the tasks page where you can view the progress of the switch.

### via the API

To trigger an event to switch the environments, run the following graphQL mutation. This will tell Lagoon to begin the process.

```graphql
mutation ActiveStandby {
  switchActiveStandby(
    input:{
      project:{
        name:"drupal-example"
      }
    }
  ){
    id
    remoteId
  }
}
```

A task is created in the current active environment `tasks` tab when a switch event is triggered. You can check the status of the switch here.

Using the `remoteId` from the `switchActiveStandby` mutation, we can also check the status of the task.

```graphql
query getTask {
  taskByRemoteId(id: "<remoteId>") {
    id
    name
    created
    started
    completed
    status
    logs
  }
}
```

## `drush` aliases

By default, projects will be created with the following aliases that will be available when active/standby is enabled on a project.

* `lagoon-production`
* `lagoon-standby`

The `lagoon-production` alias will point to whichever site is defined as `productionEnvironment`, and `lagoon-standby` will always point to the site that is defined as `standbyProductionEnvironment`.

These aliases are configurable by updating the project. Be aware that changing them may require you to update any scripts that rely on them.

```graphql
mutation updateProject {
  updateProject(input:{
    id:1234
    patch:{
      productionAlias:"custom-lagoon-production-alias"
      standbyAlias:"custom-lagoon-standby-alias"
    }
  }){
    productionAlias
    name
    standbyAlias
  }
}
```

## Notes

When the active/standby trigger has been executed, the `productionEnvironment` and `standbyProductionEnvironments` will switch within the Lagoon API. Both environments are still classed as `production` environment types. We use the `productionEnvironment` to determine which one is labelled as `active`. For more information on the differences between environment types, read the [documentation for `environment types`](environment-types.md)

```graphql
query projectByName {
  projectByName(name:"drupal-example"){
    productionEnvironment
    standbyProductionEnvironment
  }
}
```

Before switching environments:

```graphql
{
  "data": {
    "projectByName": {
      "productionEnvironment": "production-brancha",
      "standbyProductionEnvironment": "production-branchb"
    }
  }
}
```

After switching environments:

```graphql
{
  "data": {
    "projectByName": {
      "productionEnvironment": "production-branchb",
      "standbyProductionEnvironment": "production-brancha"
    }
  }
}
```

