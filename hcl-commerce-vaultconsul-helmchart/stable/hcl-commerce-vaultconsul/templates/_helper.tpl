{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Resolve the external domain name for both commerce and vault
It will use the global.domain value if it is defiend, otherwise default to common.externalDomain
This template function can be referenced in values.yaml file to help resolve external domain in
vault property values. To reference it in values.yaml, use '{{ include "external.domain" $ }}'
*/}}
{{- define "external.domain" -}}
{{- $name := default .Values.common.externalDomain .Values.global.domain -}}
{{- printf "%s" $name -}}
{{- end -}}

{{/*
Image Repository
*/}}
{{- define "supportC.image.repo" -}}
{{- $repo := "" -}}
{{- if .Values.global.sofySolutionContext -}}
{{- $repo = .Values.global.hclImageRegistry -}}
{{- else -}}
{{- $repo = .Values.supportC.imageRepo -}}
{{- end -}}
{{- if hasSuffix "/" $repo -}}
{{ print $repo }}
{{- else -}}
{{ printf "%s/" $repo }}
{{- end -}}
{{- end -}}

{{/*
Image Pull Secret
*/}}
{{- define "supportC.image.pull.secret" -}}
{{- if .Values.global.sofySolutionContext -}}
{{ .Values.global.hclImagePullSecret }}
{{- else -}}
{{ .Values.supportC.imagePullSecret }}
{{- end -}}
{{- end -}}