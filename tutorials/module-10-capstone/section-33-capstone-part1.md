# Section 33: MLOps Capstone Project - Part 1: End-to-End Pipeline

**Duration**: 4 hours  
**Level**: Advanced  
**Prerequisites**: All previous modules (Sections 1-32)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Build a complete MLOps pipeline from scratch
- ✅ Implement data ingestion, validation, and preprocessing
- ✅ Create training and evaluation pipelines
- ✅ Set up model registry and versioning
- ✅ Implement batch scoring and real-time API
- ✅ Deploy to Kubernetes with GitOps

---

## 📚 Capstone Overview

### Project: Customer Churn Prediction System

**Business Goal**: Predict which customers will churn and enable proactive retention

**Technical Requirements**:
1. Automated data pipeline (daily refresh)
2. Model retraining (weekly)
3. Batch predictions (nightly)
4. Real-time API (<100ms P95 latency)
5. Monitoring and alerting
6. 99.9% availability SLO

---

## Phase 1: Data Pipeline

### Step 1: Data Ingestion

```python
# src/churn_mlops/pipeline/ingest.py
from pathlib import Path
import pandas as pd
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

class DataIngestion:
    """Ingest customer data from multiple sources."""
    
    def __init__(self, output_dir: Path):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
    
    def run(self, start_date: str, end_date: str) -> Path:
        """
        Ingest data for date range.
        
        Args:
            start_date: Start date (YYYY-MM-DD)
            end_date: End date (YYYY-MM-DD)
        
        Returns:
            Path to ingested data
        """
        logger.info(f"Ingesting data from {start_date} to {end_date}")
        
        # 1. Extract from database
        customers = self._extract_customers(start_date, end_date)
        logger.info(f"Extracted {len(customers)} customers")
        
        # 2. Extract usage data
        usage = self._extract_usage(start_date, end_date)
        logger.info(f"Extracted {len(usage)} usage records")
        
        # 3. Extract billing data
        billing = self._extract_billing(start_date, end_date)
        logger.info(f"Extracted {len(billing)} billing records")
        
        # 4. Merge datasets
        merged = self._merge_data(customers, usage, billing)
        logger.info(f"Merged dataset: {merged.shape}")
        
        # 5. Save raw data
        output_path = self.output_dir / f"raw_{start_date}_{end_date}.parquet"
        merged.to_parquet(output_path, index=False)
        logger.info(f"Saved to {output_path}")
        
        return output_path
    
    def _extract_customers(self, start_date: str, end_date: str) -> pd.DataFrame:
        """Extract customer master data."""
        query = """
        SELECT 
            customer_id,
            signup_date,
            age,
            gender,
            location,
            contract_type,
            payment_method
        FROM customers
        WHERE signup_date BETWEEN %s AND %s
        """
        
        # Execute query (placeholder for actual DB connection)
        df = pd.read_sql(query, con=db_connection, params=(start_date, end_date))
        return df
    
    def _extract_usage(self, start_date: str, end_date: str) -> pd.DataFrame:
        """Extract usage metrics."""
        query = """
        SELECT 
            customer_id,
            AVG(data_usage_gb) as avg_data_usage,
            AVG(call_minutes) as avg_call_minutes,
            COUNT(*) as usage_days
        FROM usage_logs
        WHERE date BETWEEN %s AND %s
        GROUP BY customer_id
        """
        
        df = pd.read_sql(query, con=db_connection, params=(start_date, end_date))
        return df
    
    def _extract_billing(self, start_date: str, end_date: str) -> pd.DataFrame:
        """Extract billing information."""
        query = """
        SELECT 
            customer_id,
            AVG(monthly_charges) as avg_monthly_charges,
            SUM(CASE WHEN payment_status = 'late' THEN 1 ELSE 0 END) as late_payments,
            MAX(tenure_months) as tenure
        FROM billing
        WHERE billing_date BETWEEN %s AND %s
        GROUP BY customer_id
        """
        
        df = pd.read_sql(query, con=db_connection, params=(start_date, end_date))
        return df
    
    def _merge_data(
        self,
        customers: pd.DataFrame,
        usage: pd.DataFrame,
        billing: pd.DataFrame
    ) -> pd.DataFrame:
        """Merge all data sources."""
        # Left join to keep all customers
        merged = customers.merge(usage, on='customer_id', how='left')
        merged = merged.merge(billing, on='customer_id', how='left')
        
        return merged

# Run ingestion
if __name__ == "__main__":
    ingestion = DataIngestion(output_dir="data/raw")
    
    # Ingest last 30 days
    end_date = datetime.now()
    start_date = end_date - timedelta(days=30)
    
    output_path = ingestion.run(
        start_date=start_date.strftime("%Y-%m-%d"),
        end_date=end_date.strftime("%Y-%m-%d")
    )
    
    print(f"✅ Data ingested: {output_path}")
```

### Step 2: Data Validation

```python
# src/churn_mlops/pipeline/validate.py
from great_expectations.core import ExpectationSuite, ExpectationConfiguration
import great_expectations as ge
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

class DataValidator:
    """Validate data quality with Great Expectations."""
    
    def __init__(self, expectations_dir: Path):
        self.expectations_dir = Path(expectations_dir)
        self.context = ge.data_context.DataContext(self.expectations_dir)
    
    def create_expectations(self) -> ExpectationSuite:
        """Define data quality expectations."""
        suite = self.context.create_expectation_suite(
            "churn_data_suite",
            overwrite_existing=True
        )
        
        # Schema validation
        suite.add_expectation(
            ExpectationConfiguration(
                expectation_type="expect_table_columns_to_match_ordered_list",
                kwargs={
                    "column_list": [
                        "customer_id", "signup_date", "age", "gender",
                        "location", "contract_type", "payment_method",
                        "avg_data_usage", "avg_call_minutes", "usage_days",
                        "avg_monthly_charges", "late_payments", "tenure"
                    ]
                }
            )
        )
        
        # Completeness checks
        suite.add_expectation(
            ExpectationConfiguration(
                expectation_type="expect_column_values_to_not_be_null",
                kwargs={"column": "customer_id"}
            )
        )
        
        suite.add_expectation(
            ExpectationConfiguration(
                expectation_type="expect_column_values_to_not_be_null",
                kwargs={"column": "age"}
            )
        )
        
        # Range checks
        suite.add_expectation(
            ExpectationConfiguration(
                expectation_type="expect_column_values_to_be_between",
                kwargs={
                    "column": "age",
                    "min_value": 18,
                    "max_value": 100
                }
            )
        )
        
        suite.add_expectation(
            ExpectationConfiguration(
                expectation_type="expect_column_values_to_be_between",
                kwargs={
                    "column": "tenure",
                    "min_value": 0,
                    "max_value": 120
                }
            )
        )
        
        # Uniqueness checks
        suite.add_expectation(
            ExpectationConfiguration(
                expectation_type="expect_column_values_to_be_unique",
                kwargs={"column": "customer_id"}
            )
        )
        
        # Categorical values
        suite.add_expectation(
            ExpectationConfiguration(
                expectation_type="expect_column_values_to_be_in_set",
                kwargs={
                    "column": "gender",
                    "value_set": ["Male", "Female", "Other"]
                }
            )
        )
        
        self.context.save_expectation_suite(suite)
        return suite
    
    def validate(self, data_path: Path) -> dict:
        """
        Validate data file.
        
        Returns:
            Validation results
        """
        logger.info(f"Validating {data_path}")
        
        # Load data
        batch = self.context.get_batch(
            batch_kwargs={
                "path": str(data_path),
                "datasource": "files"
            },
            expectation_suite_name="churn_data_suite"
        )
        
        # Run validation
        results = batch.validate()
        
        # Check if validation passed
        if results["success"]:
            logger.info("✅ Validation passed")
        else:
            logger.error("❌ Validation failed")
            for result in results["results"]:
                if not result["success"]:
                    logger.error(f"  - {result['expectation_config']['expectation_type']}")
        
        return {
            "success": results["success"],
            "statistics": results["statistics"],
            "results": results["results"]
        }

# Run validation
if __name__ == "__main__":
    validator = DataValidator(expectations_dir="great_expectations")
    
    # Create expectations (first time only)
    validator.create_expectations()
    
    # Validate data
    results = validator.validate(Path("data/raw/raw_2023-11-15_2023-12-15.parquet"))
    
    if results["success"]:
        print("✅ Data validation passed")
    else:
        print("❌ Data validation failed")
        exit(1)
```

### Step 3: Feature Engineering

```python
# src/churn_mlops/pipeline/features.py
import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.preprocessing import StandardScaler, LabelEncoder
import joblib
import logging

logger = logging.getLogger(__name__)

class FeatureEngineering:
    """Create features for churn prediction."""
    
    def __init__(self, output_dir: Path):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        self.scaler = StandardScaler()
        self.encoders = {}
    
    def run(self, input_path: Path, fit: bool = True) -> Path:
        """
        Engineer features.
        
        Args:
            input_path: Path to validated data
            fit: Whether to fit transformers (train) or just transform (test)
        
        Returns:
            Path to engineered features
        """
        logger.info(f"Engineering features from {input_path}")
        
        # Load data
        df = pd.read_parquet(input_path)
        logger.info(f"Loaded {len(df)} records")
        
        # 1. Handle missing values
        df = self._impute_missing(df)
        
        # 2. Create derived features
        df = self._create_derived_features(df)
        
        # 3. Encode categorical features
        df = self._encode_categorical(df, fit=fit)
        
        # 4. Scale numerical features
        df = self._scale_numerical(df, fit=fit)
        
        # 5. Select final features
        df = self._select_features(df)
        
        logger.info(f"Final features shape: {df.shape}")
        
        # Save features
        timestamp = pd.Timestamp.now().strftime("%Y%m%d_%H%M%S")
        output_path = self.output_dir / f"features_{timestamp}.parquet"
        df.to_parquet(output_path, index=False)
        logger.info(f"Saved to {output_path}")
        
        # Save transformers (if fitting)
        if fit:
            self._save_transformers()
        
        return output_path
    
    def _impute_missing(self, df: pd.DataFrame) -> pd.DataFrame:
        """Impute missing values."""
        # Numerical: Median
        numerical_cols = df.select_dtypes(include=[np.number]).columns
        for col in numerical_cols:
            if df[col].isnull().any():
                median = df[col].median()
                df[col].fillna(median, inplace=True)
                logger.info(f"Imputed {col} with median: {median}")
        
        # Categorical: Mode
        categorical_cols = df.select_dtypes(include=['object']).columns
        for col in categorical_cols:
            if df[col].isnull().any():
                mode = df[col].mode()[0]
                df[col].fillna(mode, inplace=True)
                logger.info(f"Imputed {col} with mode: {mode}")
        
        return df
    
    def _create_derived_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Create derived features."""
        # Average revenue per month
        df['avg_revenue_per_month'] = df['avg_monthly_charges'] / (df['tenure'] + 1)
        
        # Usage intensity
        df['usage_intensity'] = df['avg_data_usage'] + df['avg_call_minutes']
        
        # Customer lifetime value estimate
        df['estimated_clv'] = df['avg_monthly_charges'] * df['tenure']
        
        # Payment reliability
        df['payment_reliability'] = 1 - (df['late_payments'] / (df['tenure'] + 1))
        
        # Tenure category
        df['tenure_category'] = pd.cut(
            df['tenure'],
            bins=[0, 6, 12, 24, 120],
            labels=['new', 'recent', 'established', 'loyal']
        )
        
        logger.info(f"Created {5} derived features")
        return df
    
    def _encode_categorical(self, df: pd.DataFrame, fit: bool) -> pd.DataFrame:
        """Encode categorical variables."""
        categorical_cols = ['gender', 'location', 'contract_type', 'payment_method', 'tenure_category']
        
        for col in categorical_cols:
            if col not in df.columns:
                continue
            
            if fit:
                # Fit encoder
                self.encoders[col] = LabelEncoder()
                df[f'{col}_encoded'] = self.encoders[col].fit_transform(df[col])
            else:
                # Transform using fitted encoder
                df[f'{col}_encoded'] = self.encoders[col].transform(df[col])
            
            # Drop original column
            df.drop(col, axis=1, inplace=True)
        
        logger.info(f"Encoded {len(categorical_cols)} categorical features")
        return df
    
    def _scale_numerical(self, df: pd.DataFrame, fit: bool) -> pd.DataFrame:
        """Scale numerical features."""
        # Select numerical columns
        numerical_cols = [
            'age', 'avg_data_usage', 'avg_call_minutes', 'usage_days',
            'avg_monthly_charges', 'late_payments', 'tenure',
            'avg_revenue_per_month', 'usage_intensity', 'estimated_clv', 'payment_reliability'
        ]
        
        numerical_cols = [col for col in numerical_cols if col in df.columns]
        
        if fit:
            # Fit scaler
            df[numerical_cols] = self.scaler.fit_transform(df[numerical_cols])
        else:
            # Transform using fitted scaler
            df[numerical_cols] = self.scaler.transform(df[numerical_cols])
        
        logger.info(f"Scaled {len(numerical_cols)} numerical features")
        return df
    
    def _select_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Select final feature set."""
        # Keep customer_id for tracking
        id_col = ['customer_id'] if 'customer_id' in df.columns else []
        
        # Drop non-feature columns
        drop_cols = ['signup_date']
        df.drop([col for col in drop_cols if col in df.columns], axis=1, inplace=True)
        
        return df
    
    def _save_transformers(self):
        """Save fitted transformers."""
        joblib.dump(self.scaler, self.output_dir / 'scaler.pkl')
        joblib.dump(self.encoders, self.output_dir / 'encoders.pkl')
        logger.info("Saved transformers")

# Run feature engineering
if __name__ == "__main__":
    fe = FeatureEngineering(output_dir="data/features")
    
    output_path = fe.run(
        input_path=Path("data/raw/raw_2023-11-15_2023-12-15.parquet"),
        fit=True  # Fit transformers on training data
    )
    
    print(f"✅ Features engineered: {output_path}")
```

---

## Phase 2: Training Pipeline

### Step 4: Model Training

```python
# src/churn_mlops/pipeline/train.py
import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score
import mlflow
import joblib
import logging

logger = logging.getLogger(__name__)

class ModelTrainer:
    """Train churn prediction model."""
    
    def __init__(self, experiment_name: str = "churn-prediction"):
        self.experiment_name = experiment_name
        mlflow.set_experiment(experiment_name)
    
    def run(self, features_path: Path, labels_path: Path) -> dict:
        """
        Train model.
        
        Args:
            features_path: Path to feature file
            labels_path: Path to labels file
        
        Returns:
            Training metrics
        """
        logger.info("Starting model training")
        
        # Load data
        X = pd.read_parquet(features_path)
        y = pd.read_parquet(labels_path)['churned']
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        
        logger.info(f"Train: {len(X_train)}, Test: {len(X_test)}")
        
        # Start MLflow run
        with mlflow.start_run() as run:
            # Log parameters
            params = {
                "max_depth": 10,
                "learning_rate": 0.1,
                "max_iter": 200,
                "min_samples_leaf": 50,
                "l2_regularization": 0.1,
                "random_state": 42
            }
            mlflow.log_params(params)
            
            # Train model
            model = HistGradientBoostingClassifier(**params)
            model.fit(X_train, y_train)
            logger.info("Model trained")
            
            # Evaluate
            metrics = self._evaluate(model, X_test, y_test)
            mlflow.log_metrics(metrics)
            
            # Log model
            mlflow.sklearn.log_model(
                model,
                "model",
                registered_model_name="churn-model"
            )
            
            logger.info(f"Model logged with run_id: {run.info.run_id}")
        
        return metrics
    
    def _evaluate(self, model, X_test, y_test) -> dict:
        """Evaluate model."""
        # Predictions
        y_pred = model.predict(X_test)
        y_proba = model.predict_proba(X_test)[:, 1]
        
        # Metrics
        metrics = {
            "accuracy": accuracy_score(y_test, y_pred),
            "precision": precision_score(y_test, y_pred),
            "recall": recall_score(y_test, y_pred),
            "f1_score": f1_score(y_test, y_pred),
            "roc_auc": roc_auc_score(y_test, y_proba)
        }
        
        logger.info(f"Metrics: {metrics}")
        return metrics

# Run training
if __name__ == "__main__":
    trainer = ModelTrainer()
    
    metrics = trainer.run(
        features_path=Path("data/features/features_20231215_120000.parquet"),
        labels_path=Path("data/labels/labels_20231215_120000.parquet")
    )
    
    print(f"✅ Model trained - Accuracy: {metrics['accuracy']:.3f}")
```

---

## Exercise: Build Your Pipeline

### Task 1: Complete the Pipeline

Create a master pipeline script that orchestrates all steps:

```python
# src/churn_mlops/pipeline/run_pipeline.py
from churn_mlops.pipeline.ingest import DataIngestion
from churn_mlops.pipeline.validate import DataValidator
from churn_mlops.pipeline.features import FeatureEngineering
from churn_mlops.pipeline.train import ModelTrainer
from datetime import datetime, timedelta
from pathlib import Path
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def run_full_pipeline():
    """Run complete MLOps pipeline."""
    try:
        # 1. Data Ingestion
        logger.info("Step 1: Data Ingestion")
        ingestion = DataIngestion(output_dir="data/raw")
        end_date = datetime.now()
        start_date = end_date - timedelta(days=30)
        raw_data_path = ingestion.run(
            start_date=start_date.strftime("%Y-%m-%d"),
            end_date=end_date.strftime("%Y-%m-%d")
        )
        
        # 2. Data Validation
        logger.info("Step 2: Data Validation")
        validator = DataValidator(expectations_dir="great_expectations")
        validation_results = validator.validate(raw_data_path)
        if not validation_results["success"]:
            raise ValueError("Data validation failed")
        
        # 3. Feature Engineering
        logger.info("Step 3: Feature Engineering")
        fe = FeatureEngineering(output_dir="data/features")
        features_path = fe.run(input_path=raw_data_path, fit=True)
        
        # 4. Model Training
        logger.info("Step 4: Model Training")
        trainer = ModelTrainer()
        metrics = trainer.run(
            features_path=features_path,
            labels_path=Path("data/labels/labels_latest.parquet")
        )
        
        logger.info("✅ Pipeline completed successfully")
        return metrics
    
    except Exception as e:
        logger.error(f"❌ Pipeline failed: {e}")
        raise

if __name__ == "__main__":
    metrics = run_full_pipeline()
    print(f"Final metrics: {metrics}")
```

### Task 2: Schedule Pipeline

Create Kubernetes CronJob:

```yaml
# k8s/cronjobs/training-pipeline.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: training-pipeline
  namespace: churn-mlops
spec:
  schedule: "0 2 * * 0"  # Weekly at 2 AM Sunday
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: pipeline
              image: churn-mlops:latest
              command:
                - python
                - -m
                - churn_mlops.pipeline.run_pipeline
              env:
                - name: MLFLOW_TRACKING_URI
                  value: "http://mlflow:5000"
          restartPolicy: OnFailure
```

---

## Key Takeaways

✅ Built complete data pipeline (ingest → validate → feature engineering)  
✅ Created training pipeline with MLflow tracking  
✅ Implemented data quality checks  
✅ Scheduled automated training

---

## Next Steps

Continue to **[Section 34: MLOps Capstone - Part 2: Deployment & Monitoring](./section-34-capstone-part2.md)**

---

**Progress**: 31/34 sections complete (91%) → **32/34 (94%)**
