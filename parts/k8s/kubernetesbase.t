{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    {{range .AgentPoolProfiles}}{{template "agentparams.t" .}},{{end}}
    {{if .HasWindows}}
      "kubeBinariesSASURL": {
        "metadata": {
          "description": "The download url for kubernetes windows binaries."
        },
        "type": "string"
      },
      "windowsPackageSASURLBase": {
        "metadata": {
          "description": "The download url base for windows packages for kubernetes."
        },
        "type": "string"
      },
      "kubeBinariesVersion": {
        "metadata": {
          "description": "Kubernetes windows binaries version"
        },
        "type": "string"
      },
      "windowsTelemetryGUID": {
        "metadata": {
          "description": "The GUID to set in windows agent to collect telemetry data."
        },
        "type": "string"
      },
      {{template "windowsparams.t"}},
    {{end}}
    {{template "masterparams.t" .}},
    {{template "k8s/kubernetesparams.t" .}}
  },
  "variables": {
    {{range $index, $agent := .AgentPoolProfiles}}
        "{{.Name}}Index": {{$index}},
        {{template "k8s/kubernetesagentvars.t" .}}
        {{if IsNSeriesSKU .}}
          {{if IsNVIDIADevicePluginEnabled}}
          "registerWithGpuTaints": "nvidia.com/gpu=true:NoSchedule",
          {{end}}
        {{end}}
        {{if .IsStorageAccount}}
          {{if .HasDisks}}
            "{{.Name}}DataAccountName": "[concat(variables('storageAccountBaseName'), 'data{{$index}}')]",
          {{end}}
          "{{.Name}}AccountName": "[concat(variables('storageAccountBaseName'), 'agnt{{$index}}')]",
        {{end}}
    {{end}}
    {{template "k8s/kubernetesmastervars.t" .}}
  },
  "resources": [
    {{if IsOpenShift}}
      {{template "openshift/infraresources.t" .}}
    {{end}}
    {{ range $index, $element := .AgentPoolProfiles}}
      {{if $index}}, {{end}}
      {{if .IsWindows}}
        {{if .IsVirtualMachineScaleSets}}
          {{template "k8s/kuberneteswinagentresourcesvmss.t" .}}
        {{else}}
          {{template "k8s/kuberneteswinagentresourcesvmas.t" .}}
        {{end}}
      {{else}}
        {{if .IsVirtualMachineScaleSets}}
          {{template "k8s/kubernetesagentresourcesvmss.t" .}}
        {{else}}
          {{template "k8s/kubernetesagentresourcesvmas.t" .}}
        {{end}}
      {{end}}
    {{end}}
    {{if not IsHostedMaster}}
      ,{{template "k8s/kubernetesmasterresources.t" .}}
    {{else}}
      {{if not IsCustomVNET}}
      ,{
        "apiVersion": "[variables('apiVersionDefault')]",
        "dependsOn": [
          "[concat('Microsoft.Network/networkSecurityGroups/', variables('nsgName'))]"
      {{if not IsAzureCNI}}
          ,
          "[concat('Microsoft.Network/routeTables/', variables('routeTableName'))]"
      {{end}}
        ],
        "location": "[variables('location')]",
        "name": "[variables('virtualNetworkName')]",
        "properties": {
          "addressSpace": {
            "addressPrefixes": [
              "[parameters('vnetCidr')]"
            ]
          },
          "subnets": [
            {
              "name": "[variables('subnetName')]",
              "properties": {
                "addressPrefix": "[parameters('masterSubnet')]",
                "networkSecurityGroup": {
                  "id": "[variables('nsgID')]"
                }
      {{if not IsAzureCNI}}
                ,
                "routeTable": {
                  "id": "[variables('routeTableID')]"
                }
      {{end}}
              }
            }
          ]
        },
        "type": "Microsoft.Network/virtualNetworks"
      }
    {{end}}
    {{if not IsAzureCNI}}
    ,{
      "apiVersion": "[variables('apiVersionDefault')]",
      "location": "[variables('location')]",
      "name": "[variables('routeTableName')]",
      "type": "Microsoft.Network/routeTables"
    }
    {{end}}
    ,{
      "apiVersion": "[variables('apiVersionDefault')]",
      "location": "[variables('location')]",
      "name": "[variables('nsgName')]",
      "properties": {
        "securityRules": [
{{if .HasWindows}}
          {
            "name": "allow_rdp",
            "properties": {
              "access": "Allow",
              "description": "Allow RDP traffic to master",
              "destinationAddressPrefix": "*",
              "destinationPortRange": "3389-3389",
              "direction": "Inbound",
              "priority": 102,
              "protocol": "Tcp",
              "sourceAddressPrefix": "*",
              "sourcePortRange": "*"
            }
          },
{{end}}
          {
            "name": "allow_ssh",
            "properties": {
              "access": "Allow",
              "description": "Allow SSH traffic to master",
              "destinationAddressPrefix": "*",
              "destinationPortRange": "22-22",
              "direction": "Inbound",
              "priority": 101,
              "protocol": "Tcp",
              "sourceAddressPrefix": "*",
              "sourcePortRange": "*"
            }
          },
          {
            "name": "allow_kube_tls",
            "properties": {
              "access": "Allow",
              "description": "Allow kube-apiserver (tls) traffic to master",
              "destinationAddressPrefix": "*",
              "destinationPortRange": "443-443",
              "direction": "Inbound",
              "priority": 100,
              "protocol": "Tcp",
              "sourceAddressPrefix": "*",
              "sourcePortRange": "*"
            }
          }
        ]
      },
      "type": "Microsoft.Network/networkSecurityGroups"
    }
    {{end}}
  ],
  "outputs": {
    {{range .AgentPoolProfiles}}{{template "agentoutputs.t" .}}
    {{end}}
    {{if IsHostedMaster}}
      {{template "iaasoutputs.t" .}}
    {{else}}
      {{template "masteroutputs.t" .}} ,
      {{template "iaasoutputs.t" .}}
    {{end}}

  }
}
