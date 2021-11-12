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
FlexNet License URL
*/}}
{{- define "license.url" -}}
{{- if .Values.hclFlexnetURL -}}
{{ tpl .Values.hclFlexnetURL . }}
{{- else if .Values.global.hclFlexnetURL -}}
{{ tpl .Values.global.hclFlexnetURL . }}
{{- end -}}
{{- end -}}

{{/*
FlexNet License ID
*/}}
{{- define "license.id" -}}
{{- if .Values.hclFlexnetID -}}
{{ tpl .Values.hclFlexnetID . }}
{{- else if .Values.global.hclFlexnetID -}}
{{ tpl .Values.global.hclFlexnetID . }}
{{- end -}}
{{- end -}}

{{/*
FlexNet License admin user for REST service authentication
*/}}
{{- define "license.user" -}}
{{- if .Values.hclFlexnetUserName -}}
{{ tpl .Values.hclFlexnetUserName . }}
{{- else if .Values.global.hclFlexnetUserName -}}
{{ tpl .Values.global.hclFlexnetUserName . }}
{{- end -}}
{{- end -}}

{{/*
FlexNet License admin password for REST service authentication
*/}}
{{- define "license.user.password" -}}
{{- if .Values.hclFlexnetUserPassword -}}
{{ tpl .Values.hclFlexnetUserPassword . }}
{{- else if .Values.global.hclFlexnetUserPassword -}}
{{ tpl .Values.global.hclFlexnetUserPassword . }}
{{- end -}}
{{- end -}}

{{/*
Image Repository
*/}}
{{- define "image.repo" -}}
{{- $repo := "" -}}
{{- if .Values.global.sofySolutionContext -}}
{{- $repo = .Values.global.hclImageRegistry -}}
{{- else -}}
{{- $repo = .Values.common.imageRepo -}}
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
{{- define "image.pull.secret" -}}
{{- if .Values.global.sofySolutionContext -}}
{{ .Values.global.hclImagePullSecret }}
{{- else -}}
{{ .Values.common.imagePullSecrets }}
{{- end -}}
{{- end -}}


{{/*
HCL Cache config map name
*/}}
{{- define "hcl.cache.configmap.name" -}}
{{- printf "%s-%s%s-hcl-cache-config" .Release.Name .Values.common.tenant .Values.common.environmentName -}}
{{- end -}}


{{/*
RWX StorageClass name
*/}}
{{- define "rwx.storageclass.name" -}}
{{- if .Values.global.sofySandboxContext -}}
{{- default .Values.global.persistence.rwxStorageClass .Values.global.persistence.testRWXStorageClass -}}
{{- else -}}
{{- default .Values.assetsPVC.storageClass .Values.global.persistence.rwxStorageClass -}}
{{- end -}}
{{- end -}}