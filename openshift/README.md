British Columbia Telemetry Warehouse
======================

## Running in OpenShift

This project uses the scripts found in [openshift-project-tools](https://github.com/BCDevOps/openshift-project-tools) to setup and maintain OpenShift environments (both local and hosted).  Refer to the [OpenShift Scripts](https://github.com/BCDevOps/openshift-project-tools/blob/master/bin/README.md) documentation for details.

**These scripts are designed to be run on the command line (using Git Bash for example) in the root `openshift` directory of your project's source code.**

### Adding a pull secret to the OpenShift project, and import Dotnet builder image

RedHat requires authentication to the image repository where the Dotnet images are stored.  Follow these steps to enable this:

1) Sign on with a free developer account to https://access.redhat.com/terms-based-registry/.  

2) Go to the Service Accounts section of the website, which as of October 2019 was in the top right of the web page.

3) Add a service account if one does not exist.

4) Once you have a service account, click on it and select the OpenShift Secret tab.

5) Click on "view its contents" at the Step 1: Download secret section.  

6) Copy the contents of the secret 

7) Import the secret into OpenShift.  Note that you will likely need to edit the name of the secret to match naming conventions.

8) In a command line with an active connection to OpenShift, and the current project set to the Tools project, run the following commands:

`oc secrets link default <SECRETNAME> --for=pull`
`oc secrets add serviceaccount/builder secrets/<SECRETNAME>`

Where `<SECRETNAME>` is the name you specified in step 7 when you imported the secret.

9) You can now import images from the Redhat repository.  For example:

`oc import-image ubi8/dotnet-50 --from=registry.redhat.io/dotnet/ubi8/dotnet-50 --confirm` 

`oc import-image rhel8/redis-6:1-21 --from=registry.redhat.io/rhel8/redis-6 --confirm`

10) Adjust your builds to use this imported image


## Running in a Local OpenShift Cluster

At times running in a local cluster is a little different than running in the production cluster.

Differences can include:
* Resource settings.
* Available image runtimes.
* Source repositories (such as your development repo).
* Etc.

To target a different repo and branch, create a `settings.local.sh` file in your project's local `openshift` directory and override the GIT parameters, for example;
```
export GIT_URI="https://github.com/bcgov/bctw-db"
export GIT_REF="openshift-updates"
```

Then run the following command from the project's local `openshift` directory:
```
genParams.sh -l
```

**Git Bash Note:  Ensure that you do not have a linux "oc" binary on your path if using Git Bash on a Windows PC to run the scripts.  A windows "oc.exe" binary will work fine.

This will generate local settings files for all of the builds, deployments, and Jenkins pipelines.
The settings in these files will be specific to your local configuration and will be applied when you run the `genBuilds.sh` or `genDepls.sh` scripts with the `-l` switch.


## Deploying your project

All of the commands listed in the following sections must be run from the root `openshift` directory of your project's source code.

### Before you begin ...

If you are updating an existing environment you will need to be conscious of retaining access to the existing data in the given environment.  User accounts, database names, and database credentials can all be affected.  The processes affecting them should be reviewed and understood before proceeding.

For example, the process of deploying and managing database credentials has changed.  The process has moved to using shared secretes that are mounted as environment variables, where previously they were provisioned as discrete environment variables in each component's environment.  Further the new deployment process, by default, will create a random set of credentials for each deployment or update (a new set every time you run `genDepls.sh`).  Being that the credentials are shared, there is a single source and place that needs to be updated.  You simply need to ensure the credentials are updated to the values expected by the pre-configured environment if needed.

### Initialization

If you are working with a new set of OpenShift projects, or you have run a `oc delete all --all` to start over, run the `initOSProjects.sh` script, this will repair the cluster file system services (in the Pathfinder environment), and ensure the deployment environments have the correct permissions to deploy images from the tools project.


