{{/*
Common labels applied to every resource.
*/}}
{{- define "monitoring-lab.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: monitoring-lab
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/*
Selector labels for a specific component.
Usage: include "monitoring-lab.selectorLabels" (dict "component" "app" "Release" .Release)
*/}}
{{- define "monitoring-lab.selectorLabels" -}}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Full name helper that prefixes the release name.
*/}}
{{- define "monitoring-lab.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end }}
