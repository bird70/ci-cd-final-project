::page{title="CI/CD with OpenShift Pipelines"}

<img src="https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/IDSN-logo.png" width="200">

**Estimated time needed:** 45 minutes

Welcome to the hands-on lab for **CI/CD with OpenShift Pipelines**. In this lab, you will create a CI/CD workflow using the OpenShift Pipelines.


## Learning Objectives

After completing this lab, you will be able to:

- Create a CI/CD workflow using the OpenShift Pipelines
- Add parameters to tasks created using OpenShift Pipelines
- Add a workspace and persistant volume claim in the OpenShift UI
- Add tasks that clone the GitHub repository, lint the source code, run unit tests and finally deploy the application to the OpenShift cluster

::page{title="Set Up the Lab Environment"}

You have a little preparation to do before you can start the lab.

## Open a Terminal

Open a terminal window by using the menu in the editor: Terminal > New Terminal.

![Terminal](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/01_terminal.png "New Terminal option on Terminal menu")

In the terminal, if you are not already in the `/home/project` folder, change to your project folder now.

```bash
cd /home/project
```

You can use the following command to ensure you are connected to an OpenShift cluster:
```bash
oc config current-context
```

You should see something like:
```
captainfedo1-context
```

You are now ready to continue installing the **Prerequisites**.

### Optional

If working in the terminal becomes difficult because the command prompt is very long, you can shorten the prompt using the following command:

```bash
export PS1="[\[\033[01;32m\]\u\[\033[00m\]: \[\033[01;34m\]\W\[\033[00m\]]\$ "
```

---

::page{title="Prerequisites"}

This lab requires installation of the tasks introduced in the previous labs. To be sure, apply the previous tasks to your cluster before proceeding. Reissue these commands:

### Establish the Tasks

First create an empty file called `tasks.yaml` in the root folder:

```bash
touch tasks.yaml
```

Open the `tasks.yaml` file and add the following yaml content.

::openFile{path="/home/project/tasks.yaml"}

```
---
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: cleanup
spec:
  description: This task will clean up a workspace by deleting all the files.
  workspaces:
    - name: source
  steps:
    - name: remove
      image: alpine:3
      env:
        - name: WORKSPACE_SOURCE_PATH
          value: $(workspaces.source.path)
      workingDir: $(workspaces.source.path)
      securityContext:
        runAsNonRoot: false
        runAsUser: 0
      script: |
        #!/usr/bin/env sh
        set -eu
        echo "Removing all files from ${WORKSPACE_SOURCE_PATH} ..."
        # Delete any existing contents of the directory if it exists.
        #
        # We don't just "rm -rf ${WORKSPACE_SOURCE_PATH}" because ${WORKSPACE_SOURCE_PATH} might be "/"
        # or the root of a mounted volume.
        if [ -d "${WORKSPACE_SOURCE_PATH}" ] ; then
          # Delete non-hidden files and directories
          rm -rf "${WORKSPACE_SOURCE_PATH:?}"/*
          # Delete files and directories starting with . but excluding ..
          rm -rf "${WORKSPACE_SOURCE_PATH}"/.[!.]*
          # Delete files and directories starting with .. plus any other character
          rm -rf "${WORKSPACE_SOURCE_PATH}"/..?*
        fi

---
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: nose
spec:
  workspaces:
    - name: source
  params:
    - name: args
      description: Arguments to pass to nose
      type: string
      default: "-v"
  steps:
    - name: nosetests
      image: python:3.9-slim
      workingDir: $(workspaces.source.path)
      script: |
        #!/bin/bash
        set -e
        python -m pip install --upgrade pip wheel
        pip install -r requirements.txt
        nosetests $(params.args)
```

Make sure you save the file. Next, apply the tasks to your OpenShift Cluster:

```bash
kubectl apply -f tasks.yaml
```

Check that you have all of the previous tasks installed:

```bash
oc get tasks
```

You should see the output similar to this:
```
NAME      AGE
cleanup   5h42m
nose      5h42m
```

::page{title="Step 1: Create PersistentVolumeClaim"}

You also need a PersistentVolumeClaim (PVC) to use as a workspace. You can use the OpenShift Administrator perspective to create the PVC.

Open the OpenShift console using the **Open OpenShift Console** under the **Skills Network Toolbox** menu.

![Open OpenShift Console](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-open-console.png "Open OpenShift Console")

The lab should open the **Developer** perspective for the OpenShift console in a new tab.

![OpenShift Developer Perspective](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-console-landing.png "OpenShift Developer Perspective")

Open the **Administrator** perspective using the drop down on the left side of the screen.

![Launch Administrator Perspective](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-console-administator-launch.png "Launch Administrator Perspective")

Once the page switches to the Administrator view, click **Storage** and **PersistantVolumeClaims**.

![Create a new Persistent Volume Claim](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-console-pvc-page.png "Create a new Persistent Volume Claim")

***Note:** If you encounter an error when opening OpenShift and accessing the Persistent Claim value, please close the OpenShift window and then reopen it.*

Click `Create PersistentVolumeClaim` to create a new PVC:

![Cick on Persistent Volume Claim](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-console-pvc-add.png "Cick on Persistent Volume Claim")

Next, fill out the form as follows:
- StorageClass: `skills-network-learner`
- PersistantVolumenClaim name: `oc-lab-pvc`
- Size: `1GB`

![Persistent Volume Claim Details](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-console-pvc-form.png "Persistent Volume Claim Details")

Finally, click `Create` to create the PVC. Once the PVC is created, you should see the details. Notice the **Status** is **Pending**. It takes a few minutes for the PVC to complete. You don\'t have to wait for this to finish as it will most likely be in place by the time you need it in the pipeline.

![Persistent Volume Claim Pending](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-console-pvc-details.png "Persistent Volume Claim Pending")

---

*Note:- In case you face permission security error in the OpenShift Console while creating a PVC, you can create a pvc through terminal using the steps below:-*

**Option 2 for creating a PVC through terminal:-**

You start by creating a `PersistentVolumeClaim` (PVC) to use as the workspace:

A workspace is a disk volume that can be shared across tasks. The way to bind to volumes in Kubernetes is with a `PersistentVolumeClaim`.

Create a `pvc.yaml` file with these contents:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pipelinerun-pvc
spec:
  storageClassName: skills-network-learner
  resources:
    requests:
      storage:  1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
```

Apply the new task definition to the cluster:

```bash
kubectl apply -f pvc.yaml
```

You should see the following output:

```text
persistentvolumeclaim/pipelinerun-pvc created
```

You can now use this persistent volume `pipelinerun-pvc` as a workspace in your Tekton tasks by selecting it from the dropdown in the OpenShift Console.

::page{title="Step 2: Create a new Pipeline"}

Now that you have a PVC in place, the next step is start working on the pipeline. First, go back to the **Developer** perspective.

![Switch to Developer perspective](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-developer-perspective.png "Switch to Developer perspective")

Next, click **Pipelines** on the left panel and create a new pipeline.

![Create new pipeline](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-create-new.png "Create new pipeline")

You are presented with the pipeline builder. Ensure you have **Pipeline Builder**  selected in **Configure Via** and enter **ci-cd-pipeline** as the name of your pipeline.

![Name the pipeline](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-create-name.png "Name the pipeline")

Before you create your first task, let\'s add a workspace to your pipeline. Scroll to the bottom of the page and add a new workspace with the name `output`. This workspace will be used to clone the code.

![Create output workspace](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-create-workspace.png "Create output workspace")

Great! We can now start adding tasks to your pipeline.

---

::page{title="Step 3: Add the cleanup task"}

You were asked to apply a `tasks.yaml` file that contained the `cleanup` and the `nose` tasks. You can confirm the tasks are installed by using the following command:
```
oc get tasks
```

You should see the output similar to this:
```
NAME      AGE
cleanup   5h42m
nose      5h42m
```

If you don\'t see both of these tasks, go back to the `Preqrequisites` step and make sure you apply the tasks.yaml file.

You will create the first task in this step. Click **Add Task** in the builder UI to open the `Add task ...` dialog.

![Create cleanup task](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-clean-task-click.png "Create cleanup task")

Type `cleanup` to see the task you installed earlier from the yaml file. Click **Add** to use the task in the builder.

![Show clean up task](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-clean-task-show.png "Show clean up task")

This should install your first task. You will notice the red exclamation mark on the task. This means the task has not been completely configured yet. Click on the task to open the task flyout. Change the workspace to **output**.

![configure clean up task](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-clean-task-configure.png "configure clean up task")

You should see the exclamation mark go away and **Create** enabled. Click **Create** to finish creating the task in the pipeline.

![Add workspace to clean up task](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-clean-task-add-workspace.png "Add workspace to clean up task")

You should now see your pipeline with the one task you just added.

![Finish pipeline](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-clean-task-finish.png "Finish pipeline")

---

::page{title="Step 4: Run the Pipeline"}

Now that you have a pipeline with the one cleanup step, let\'s see how you can run this pipeline. Click **Pipelines** on the left bar, if you are not already on the pipelines page. Click on **ci-cd-pipeline** pipeline. You can now use the **Actions** dropdown on the left to run the pipeline.

![run clean up task pipeline](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-clean-task-run.png "run clean up task pipeline")

OpenShift brings up the **Start Pipeline** dialog box. Ensure that you pick the following:
- output: `PersistentVolumeClaim`
- select a PVC: `oc-lab-pvc`

Click **Start** after you have filled out the form.

![configure pipeline](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-clean-task-pipeline-configure.png "configure pipeline")

You should see the pipeline running on the next page. You can click on the task name to see the logs for a particular task. Alternatively, you can click on the **Logs** tab:

![See logs for running pipeline](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-clean-task-pipeline-started.png "See logs for running pipeline")

You can see the detailed logs and also have an option to download them. You will see the task on the right turn green, if it completes successfully.

![Clean up pipeline finished successfully](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-clean-task-pipeline-logs.png "Clean up pipeline finished successfully")

Congratulations! You created a pipeline from scratch and added the cleanup tasks on it. You then ran the pipeline and viewed the logs. This first task was explained in detail as an example. The lab is now asking you to finish the rest of the tasks in this pipeline on your own.Good luck!

---

::page{title="Step 5: Add the Git Clone task"}

You are asked to use the `git-clone` in-built task to clone the GitHub code into your pipeline.

### Your Task
1. Open the pipeline in edit mode. Select Pipeline from the left menu, select the pipeline name, and the go to Actions -> Edit Pipeline. See hint for a screenshot.
2. Add a new task after the cleanup task in the pipeline from previous step. Hover over the step to display the `+` buttons. Use the `+` button on the right of the task to add a task instead of using the `Add finally task` link. See hint for a screenshot.
3. Look for the `RedHat git-clone` task and add it to the placeholder task.
4. Click on the red exclaimation on the task or the task card to open the configure task flyout. Configure the `git-clone` task as follows:
   - url: `https://github.com/ibm-developer-skills-network/wtecc-CICD_PracticeCode`
   - workspace.output: `output`
5. Save the pipeline.
6. Run the pipeline.
7. Check the logs to see if there are issues with the pipeline.

### Hint

<details>
<summary>Click here for a hint.</summary>

1. To open a pipeline in edit mode, select Pipeline from the left menu, select the pipeline name, and the go to Actions -> Edit Pipeline.
	![Edit a pipeline](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-edit-pipeline.png "Edit a pipeline")
1. When adding a task, use the `+` button to create a new task block. The `+` button only appear if you hover over the previous task.
	![Use plus button for new task](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-plus-new-task.png "Use plus button for new task")
This should create an empty block. Click on the block and fill in the task.
	![Fill empty task](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-new-task-block.png "Fill empty task")
1. There could be multiple tasks called `git-clone` in the task search dialog. Ensure that you pick the one by `Redhat`

	![Git clone task by RedHat](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-git-clone-hint-redhat.png "Git clone task by RedHat")
1. Click on the exclamation mark to open the task flyout. You should fill it out as follows:

	![Git Clone Flyout](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-git-clone-flyout.png "Git Clone Flyout")
</details>

### Check your Solution

<details>
	<summary>Click here for the solution.</summary>

If the pipeline ran successfully, you should see both tasks in green in the logs tab:

![Pipeline run for git clone task](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-git-clone-logs.png "Pipeline run for git clone task")

If you complete the task successfully, your pipeline should look as follows:

![Final pipeline after git-clone task](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-git-clone-final.png "Final pipeline after git-clone task")
</details>


---

::page{title="Step 6: Add the Flake8 task"}

You are asked to use the `Flake8` in-built task to lint the source code. As part of this task, you will configure the task with specific arguments.

### Your Task
1. Open the pipeline in edit mode.
2. Add a new task after the git-clone task in the pipeline from previous step.
3. Look for the `Flake8` task from the community.
4. Install and add it to the placeholder task.
5. Click on the red exclaimation on the task or the task card to open the configure task flyout. Configure the `Flake8` task as follows:
   - image: `python:3.9-slim`
   - arg: `--count`
   - arg: `--max-complexity=10`
   - arg: `--max-line-length=127`
   - workspace.source: `output`
6. Save the pipeline.
7. Run the pipeline.
8. Check the logs to see if there are issues with the pipeline.

> Note: If you encounter an error stating: flake8 not found, kindly run the following command in the terminal window to install flake8:

**Option 1: Discover via Artifact Hub and apply the raw manifest**
```bash
kubectl apply -f https://github.com/tektoncd/catalog/raw/main/task/flake8/0.1/flake8.yaml
```

**Option 2: Install directly from the Tekton Catalog**


```bash
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/flake8/0.1/flake8.yaml
```
### Hint
<details>
<summary>Click here for a hint.</summary>

Ensure the configuration is as follows:

![Configure Flake8 task](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-flake8-args.png "Configure Flake8 task")
</details>


### Check your Solution

<details>
<summary>Click here for the solution.</summary>

If the pipeline ran successfully, you should see both tasks in green in the logs tab:

![Linking job is successfull](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-flake8-hint-green.png "Linking job is successfull")

If you complete the task successfully, your pipeline should look as follows:

![Pipeline after adding flake8 task](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-flake8-hint-final.png "Pipeline after adding flake8 task")
</details>

---

::page{title="Step 7: Add the Nose task"}

The next step is to add the `nose` task for unit testing the source code of the application.

### Your Task
1. Open the pipeline in edit mode.
2. Add a new task after the Flake8 task in the pipeline from previous step.
3. Look for the `nose` task.
4. Install and add it to the placeholder task.
	
5. Click on the red exclaimation on the task or the task card to open the configure task flyout. Configure the `nose` task as follows:
   - workspace.source: `output`
6. Save the pipeline.
7. Run the pipeline.
8. Check the logs to see if there are issues with the pipeline.

### Check your Solution

<details>
<summary>Click here for the solution.</summary>

If the pipeline ran successfully, you should see all tasks in green in the logs tab. You should also see the output from the `nose` task indicating all tests have passed successfully.

![Nose task passed](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-nose-green.png "Nose task passed")

If you complete the task successfully, your pipeline should look as follows:

![Pipeline after nose task](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-nose-final.png "Pipeline after nose task")
</details>

---

::page{title="Step 8: Add the buildah task"}

The next step is to add a task to create an image from the GitHub source code. You will use the `buildah` in-built task to perform this action.

### Your Task
1. Open the pipeline in edit mode.
2. Add a new task after the nose task in the pipeline from previous step.
3. Look for the `buildah` task from RedHat.
4. Install and add it to the placeholder task.
4. You will need the namespace of your lab environment for one of the arguments. You can obtain this by using the command line terminal and using the `echo $SN_ICR_NAMESPACE` command in the lab terminal.

	```bash
	echo $SN_ICR_NAMESPACE
	```
5. Click on the red exclaimation on the task or the task card to open the configure task flyout. Configure the `buildah` task as follows:
   - image: `$(params.build-image)`
   - workspace.source: `output`
6. Click on the main page to close the flyout. Add the following parameter and the default value to the pipeline:
   - parameter.name: `build-image`
   - parameter.default: `image-registry.openshift-image-registry.svc:5000/SN_ICR_NAMESPACE/tekton-lab:latest`.
   - Replace `SN_ICR_NAMESPACE` with the value above.
7. Save the pipeline.
8. Run the pipeline.
9. Check the logs to see if there are issues with the pipeline.

### Hint

<details>
<summary>Click here for a hint.</summary>

1. Ensure you filled out the `IMAGE` parameter with `$(params.build-image)`.

	![Buildah image parameter](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-buildah-image.png "Buildah image parameter")

2. Create a pipeline parameter with the name `build-image` and the default value `image-registry.openshift-image-registry.svc:5000/SN_ICR_NAMESPACE/tekton-lab:latest` where `SN_ICR_NAMESPACE` is namespace of your lab environment.

   ![Buildah parameters](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-buildah-params.png "Buildah parameters")
</details>


### Check your Solution

<details>
<summary>Click here for the solution.</summary>

If the pipeline ran successfully, you should see all tasks in green in the logs tab. You should also see the output from the `buildah` task indicating all tests have passed successfully.

![Build task completion](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-buildah-green.png "Build task completion")

If you complete the task successfully, your pipeline should look as follows:

![Buildah task final](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-buildah-final.png "Buildah task final")
</details>


---

::page{title="Step 9: Deploy Application"}

Next, you will create a task to deploy the image you created to the lab OpenShift cluster. You will use the `OpenShift client` task to execute the `oc deploy` command with the image you built in the previous step.

### Your Task
1. Open the pipeline in edit mode.
2. Add a new task after the buildah task in the pipeline from the previous step.
3. Look for the `openshift-client` task from RedHat.
4. Install and add it to the placeholder task.
5. Click on the red exclaimation on the task or the task card to open the configure task flyout. Configure the task with the following
   - display name: `deploy`
   - SCRIPT: `oc create deployment $(params.app-name) --image=$(params.build-image) --dry-run=client -o yaml | oc apply -f -`
6. Click on the main page to close the flyout. Add the following parameter and the default value to the pipeline:
   - parameter.name: `app-name`
   - parameter.default: `cicd-app`.
7. Save the pipeline.
8. Run the pipeline.
9. Check the logs to see if there are issues with the pipeline.

### Hint

<details>
<summary>Click here for a hint.</summary>

1. Ensure the parameter is set as follows:

![Deploy task param](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-oc-params.png "Deploy task param")
</details>


### Check your Solution

<details>
<summary>Click here for the solution.</summary>

If the pipeline ran successfully, you should see all tasks in green in the logs tab. You should also see the output from the `deploy` task indicating all tests have passed successfully.

![Deploy task green](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-oc-green.png "Deploy task green")


If you complete the task successfully, your pipeline should look as follows:

![Deploy task final](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-oc-final.png "Deploy task final")
</details>


::page{title="Step 10: Validate Application"}

You have done all the hard work! Let\'s confirm if the application was deployed.

## Your Tasks
1. Click on `Topology` on the left panel in the `Developer` perspective. You should see two applications on the canvas.
	![OpenShift Topology](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-app-topology.png "OpenShift Topology")
2. Click on the one called `cicd-app` to open the flyout. Click on `logs`.
	![Open application logs](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-app-flyout.png "Open application logs")
3. You should see a message `SERVICERUNNING` in the logs indicating the application was deployed successfully and is running.
	![Application logs](https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-CD0215EN-SkillsNetwork/images/oc-pipelines-app-logs.png "Application logs")

::page{title="Conclusion"}

Congratulations! You have just created a CI/CD workflow using OpenShift Pipelines without writing a single line of code!

In this lab, you learned how to use the OpenShift UX and the Pipelines feature. You learned how to modify your pipeline in the UX to reference the task and configure its parameters. You also learned how to create default parameters for your pipeline. Finally, you now know how to create a PersistentVolumeClaim using the UX.

## Next Steps

Congratulations on successfully completing this lab! Your dedication and effort have paid off, and you\'re now equipped with the skills and knowledge to tackle the exciting final project of this course. This project will be a culmination of all that you\'ve learned, allowing you to put your newfound expertise into practice.

If you are interested in continuing to learn about Kubernetes and containers, you can get your own [free Kubernetes cluster](https://www.ibm.com/cloud/container-service/?utm_source=skills_network&utm_content=in_lab_content_link&utm_id=Lab-IBM-CD0215EN-SkillsNetwork) and your own free [IBM Container Registry](https://www.ibm.com/cloud/container-registry?utm_source=skills_network&utm_content=in_lab_content_link&utm_id=Lab-IBM-CD0215EN-SkillsNetwork).

## Author(s)
Skills Network

<!--
### Other Contributor(s)


## Change Log
| Date | Version | Changed by | Change Description |
|------|--------|--------|---------|
| 2023-08-27 | 0.1 | UL | Initial version created |
| 2023-08-31 | 0.2 | Anita Narain | ID Review |
| 2023-09-01 | 0.3 | Mercedes Schneider | QA Review |
| 2023-09-04 | 0.4 | UL | Added toggles for hint and solutions |
| 2023-09-04 | 0.4 | UL | Clarified instructions on how to configure all tasks |
| 2025-02-05 | 0.5 | Lavanya R | Updated Note for flake8 step  |
| 2026-01-14 | 0.6 | Ritika Joshi | Updated tekton hub verbiage and commnds as they are deprecated|
| 2026-02-10 | 0.7 | Ritika Joshi | Updated option 1 and 2 for Flak8 command |
	

-->

## <h3 align="center"> &#169; IBM Corporation. All rights reserved. <h3/>
