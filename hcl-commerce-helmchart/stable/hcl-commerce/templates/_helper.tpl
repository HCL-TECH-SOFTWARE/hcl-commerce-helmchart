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
{{- if .Values.commercenfs.enabled -}}
{{- printf "%s-%s" .Release.Namespace .Values.commercenfs.storageClass.name | trunc 63 }}
{{- else if .Values.global.sofySandboxContext -}}
{{- default .Values.global.persistence.rwxStorageClass .Values.global.persistence.testRWXStorageClass -}}
{{- else -}}
{{- default .Values.assetsPVC.storageClass .Values.global.persistence.rwxStorageClass -}}
{{- end -}}
{{- end -}}

{{/*
RWX shardA StorageClass name
*/}}
{{- define "rwx.shardA.storageclass.name" -}}
{{- if .Values.searchAppMaster.shardA.persistence.storageClass -}}
{{- default .Values.searchAppMaster.shardA.persistence.storageClass -}}
{{- else if .Values.commercenfs.enabled -}}
{{- printf "%s-%s" .Release.Namespace .Values.commercenfs.storageClass.name | trunc 63 }}
{{- else if .Values.global.sofySandboxContext -}}
{{- default .Values.global.persistence.rwxStorageClass .Values.global.persistence.testRWXStorageClass -}}
{{- else -}}
{{- default .Values.global.persistence.rwxStorageClass -}}
{{- end -}}
{{- end -}}

{{/*
RWX shardB StorageClass name
*/}}
{{- define "rwx.shardB.storageclass.name" -}}
{{- if .Values.searchAppMaster.shardB.persistence.storageClass -}}
{{- default .Values.searchAppMaster.shardB.persistence.storageClass -}}
{{- else if .Values.commercenfs.enabled -}}
{{- printf "%s-%s" .Release.Namespace .Values.commercenfs.storageClass.name | trunc 63 }}
{{- else if .Values.global.sofySandboxContext -}}
{{- default .Values.global.persistence.rwxStorageClass .Values.global.persistence.testRWXStorageClass -}}
{{- else -}}
{{- default .Values.global.persistence.rwxStorageClass -}}
{{- end -}}
{{- end -}}

{{/*
RWX shardC StorageClass name
*/}}
{{- define "rwx.shardC.storageclass.name" -}}
{{- if .Values.searchAppMaster.shardC.persistence.storageClass -}}
{{- default .Values.searchAppMaster.shardC.persistence.storageClass -}}
{{- else if .Values.commercenfs.enabled -}}
{{- printf "%s-%s" .Release.Namespace .Values.commercenfs.storageClass.name | trunc 63 }}
{{- else if .Values.global.sofySandboxContext -}}
{{- default .Values.global.persistence.rwxStorageClass .Values.global.persistence.testRWXStorageClass -}}
{{- else -}}
{{- default .Values.global.persistence.rwxStorageClass -}}
{{- end -}}
{{- end -}}

{{/*
RWX search StorageClass name
*/}}
{{- define "rwx.search.storageclass.name" -}}
{{- if .Values.searchAppMaster.persistence.storageClass -}}
{{- default .Values.searchAppMaster.persistence.storageClass -}}
{{- else if .Values.commercenfs.enabled -}}
{{- printf "%s-%s" .Release.Namespace .Values.commercenfs.storageClass.name | trunc 63 }}
{{- else if .Values.global.sofySandboxContext -}}
{{- default .Values.global.persistence.rwxStorageClass .Values.global.persistence.testRWXStorageClass -}}
{{- else -}}
{{- default .Values.global.persistence.rwxStorageClass -}}
{{- end -}}
{{- end -}}