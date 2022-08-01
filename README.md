# Create Recovery Partition on the same HDD - Criar partição de recuperação do Windows

Digamos que voce tenha um cenario onde não seja possivel baixar uma imagem do Windows utilizando o WDS, SCCM, Intune em PXE devido a baixa capacidade de conectividade, como faria para recuperar um SO com Windows rapidamente? Uma solução simples sem necessidade de utilização de um WinPE, Ghost, Hirens ou Pendrive de instalação seria criar uma unidade de recuperação. Isso permite que o proprio usuário faça o processo de formatação. 

Vou compartilhar por aqui um projeto rapido para isso. O deploy do scritp em Powershell pode ser realizado por SCCM ou neste caso utilizamos o Landesk nos computadores alvo. 

# Sites de referência.

Customize seu projeto de acordo com sua necessidade. 

Aqui alguns links para ajudar na construção.

[Crie um script para identificar as partições de recuperação link](https://docs.microsoft.com/pt-br/previous-versions/windows/it-pro/windows-8.1-and-8/hh824917(v=win.10))


[Tipo de partição](https://docs.microsoft.com/pt-br/windows-hardware/customize/desktop/unattend/microsoft-windows-setup-diskconfiguration-disk-createpartitions-createpartition-type)


# Script completo Powershell

[Script Powershell Recovery Partition](https://github.com/alexandrecoradi/CreateRecoveryPartition/blob/main/RecoveryPartition.ps1)
