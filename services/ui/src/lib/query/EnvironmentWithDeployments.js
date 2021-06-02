import gql from 'graphql-tag';
import DeploymentFragment from 'lib/fragment/Deployment';

export default gql`
  query getEnvironment($openshiftProjectName: String!) {
    environment: environmentByOpenshiftProjectName(
      openshiftProjectName: $openshiftProjectName
    ) {
      id
      name
      openshiftProjectName
      project {
        id
        name
        problemsUi
        factsUi
      }
      deployType
      deployBaseRef
      deployHeadRef
      deployTitle
      deployments {
        ...deploymentFields
      }
    }
  }
  ${DeploymentFragment}
`;
