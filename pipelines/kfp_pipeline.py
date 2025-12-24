"""
Kubeflow Pipelines template that reuses the existing churn-mlops scripts.

Prereqs:
- Push the churn-ml image to ECR (contains scripts).
- KFP installed on EKS.
- S3 bucket/IRSA for data/artifacts.
- Optional: MLflow server URL + S3 artifact store.

Usage:
  python pipelines/kfp_pipeline.py --compile
Then upload churn_pipeline.yaml to the KFP UI.
"""

from kfp import compiler, dsl


# Update these defaults for your ECR repo and bucket
CHURN_ML_IMAGE = "public.ecr.aws/REPLACE/churn-ml:latest"
S3_BUCKET = "s3://REPLACE-ME-BUCKET/churn-mlops-prod-v2"


def churn_pipeline(
    config_path: str = "/app/config/config.yaml",
    mlflow_tracking_uri: str = "",
    mlflow_s3_endpoint: str = "",
):
    common_env = {
        "CHURN_MLOPS_CONFIG": config_path,
        "MLFLOW_TRACKING_URI": mlflow_tracking_uri,
        "MLFLOW_S3_ENDPOINT_URL": mlflow_s3_endpoint,
    }

    generate = dsl.ContainerOp(
        name="generate-data",
        image=CHURN_ML_IMAGE,
        command=["bash", "-c", "./scripts/generate_data.sh"],
        file_outputs={},
        pvolumes={},
        env=common_env,
    )

    validate = dsl.ContainerOp(
        name="validate-data",
        image=CHURN_ML_IMAGE,
        command=["bash", "-c", "./scripts/validate_data.sh"],
        env=common_env,
    ).after(generate)

    prepare = dsl.ContainerOp(
        name="prepare-data",
        image=CHURN_ML_IMAGE,
        command=["bash", "-c", "./scripts/prepare_data.sh"],
        env=common_env,
    ).after(validate)

    features = dsl.ContainerOp(
        name="build-features",
        image=CHURN_ML_IMAGE,
        command=["bash", "-c", "./scripts/build_features.sh"],
        env=common_env,
    ).after(prepare)

    labels = dsl.ContainerOp(
        name="build-labels",
        image=CHURN_ML_IMAGE,
        command=["bash", "-c", "./scripts/build_labels.sh"],
        env=common_env,
    ).after(features)

    training_set = dsl.ContainerOp(
        name="build-training-set",
        image=CHURN_ML_IMAGE,
        command=["bash", "-c", "./scripts/build_training_set.sh"],
        env=common_env,
    ).after(labels)

    train = dsl.ContainerOp(
        name="train-baseline",
        image=CHURN_ML_IMAGE,
        command=["bash", "-c", "./scripts/train_baseline.sh"],
        env=common_env,
    ).after(training_set)

    promote = dsl.ContainerOp(
        name="promote-model",
        image=CHURN_ML_IMAGE,
        command=["bash", "-c", "./scripts/promote_model.sh"],
        env=common_env,
    ).after(train)

    # Optional: push artifacts to S3 via DVC or plain aws cli
    push_artifacts = dsl.ContainerOp(
        name="push-artifacts",
        image=CHURN_ML_IMAGE,
        command=[
            "bash",
            "-c",
            "aws s3 sync data {bucket}/data && aws s3 sync artifacts {bucket}/artifacts",
        ],
        arguments=[],
        env=common_env,
    ).after(promote)

    return push_artifacts


if __name__ == "__main__":
    compiler.Compiler().compile(churn_pipeline, package_path="churn_pipeline.yaml")
