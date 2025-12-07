{{- define "churn-mlops.name" -}}
churn-mlops
{{- end -}}

{{- define "churn-mlops.labels" -}}
app.kubernetes.io/name: {{ include "churn-mlops.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "churn-mlops.apiImage" -}}
{{- printf "%s:%s" .Values.images.api.repository .Values.images.api.tag -}}
{{- end -}}

{{- define "churn-mlops.mlImage" -}}
{{- printf "%s:%s" .Values.images.ml.repository .Values.images.ml.tag -}}
{{- end -}}

{{- define "churn-mlops.busyboxImage" -}}
{{- printf "%s:%s" .Values.images.busybox.repository .Values.images.busybox.tag -}}
{{- end -}}
