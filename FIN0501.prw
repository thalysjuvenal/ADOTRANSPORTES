#Include "Totvs.ch"

/*/{Protheus.doc} FIN0501

    Inclui o titulo no contas a pagar

@author Thalys Augusto
@since 08/11/2024
@version 1.0
@type function
/*/
User Function FIN0501()
	Local aArea := FWGetArea()
	Local cDirIni := GetTempPath()
	Local cTipArq := 'Arquivos com separações (*.csv) | Arquivos texto (*.txt) | Todas extensões (*.*)'
	Local cTitulo := 'Seleção de Arquivos para Processamento'
	Local lSalvar := .F.
	Local cArqSel := ''

	//Se não estiver sendo executado via job
	If ! IsBlind()

		//Chama a função para buscar arquivos
		cArqSel := tFileDialog(;
			cTipArq,;  // Filtragem de tipos de arquivos que serão selecionados
			cTitulo,;  // Título da Janela para seleção dos arquivos
			,;         // Compatibilidade
			cDirIni,;  // Diretório inicial da busca de arquivos
			lSalvar,;  // Se for .T., será uma Save Dialog, senão será Open Dialog
			;          // Se não passar parâmetro, irá pegar apenas 1 arquivo; Se for informado GETF_MULTISELECT será possível pegar mais de 1 arquivo; Se for informado GETF_RETDIRECTORY será possível selecionar o diretório
			)

		//Se tiver o arquivo selecionado e ele existir
		If ! Empty(cArqSel) .And. File(cArqSel)
			Processa({|| fImporta(cArqSel) }, 'Importando...')
		EndIf
	EndIf

	FWRestArea(aArea)
Return

/*/{Protheus.doc} fImporta
Função que processa o arquivo e realiza a importação para o sistema
@author Thalys Augusto
@since 25/11/2024
@version 1.0
@type function
/*/
Static Function fImporta(cArqSel)
	Local cDirTmp          := GetTempPath()
	Local cArqLog          := 'importacao_' + dToS(Date()) + '_' + StrTran(Time(), ':' , '-' ) + '.log'
	Local nTotLinhas       := 0
	Local cLinAtu          := ''
	Local nLinhaAtu        := 0
	Local aLinha           := {}
	Local oArquivo
	Local cLog             := ''
	//Local lIgnor01         := FWAlertYesNo( 'Deseja ignorar a linha 1 do arquivo?' , 'Ignorar?' )
	Local cPastaErro       := '\x_logs\'
	Local cNomeErro        := ''
	Local cTipoOper        := ""
	Local cTextoErro       := ''
	Local cCGC             := ''
	Local cData            := ''
	Local cPrefix          := ''
	Local cParcela := ''
	Local cTpNF := ""
	Local aLogErro         := {}
	Local nLinhaErro       := 0
	Local nValor           := 0
	//Variáveis do ExecAuto
	Private cAliasSA2      := GetNextAlias()
	Private aDados         := {}
	Private lMSHelpAuto    := .T.
	Private lAutoErrNoFile := .T.
	Private lMsErroAuto    := .F.
	//Variáveis da Importação
	Private cAliasImp      := 'SE2'
	Private cSeparador     := ';'

	//Abre as tabelas que serão usadas
	DbSelectArea(cAliasImp)
	(cAliasImp)->(DbSetOrder(1))
	(cAliasImp)->(DbGoTop())

	//Definindo o arquivo a ser lido
	oArquivo := FWFileReader():New(cArqSel)

	//Se o arquivo pode ser aberto
	If (oArquivo:Open())

		//Se não for fim do arquivo
		If ! (oArquivo:EoF())

			//Definindo o tamanho da régua
			aLinhas := oArquivo:GetAllLines()
			nTotLinhas := Len(aLinhas)
			ProcRegua(nTotLinhas)

			//Método GoTop não funciona (dependendo da versão da LIB), deve fechar e abrir novamente o arquivo
			oArquivo:Close()
			oArquivo := FWFileReader():New(cArqSel)
			oArquivo:Open()

			//Caso você queira, usar controle de transação, descomente a linha abaixo (e a do End Transaction), mas tem algumas rotinas que podem ser impactadas via ExecAuto
			//Begin Transaction

			//Enquanto tiver linhas
			While (oArquivo:HasLine())

				//Incrementa na tela a mensagem
				nLinhaAtu++
				IncProc('Analisando linha ' + cValToChar(nLinhaAtu) + ' de ' + cValToChar(nTotLinhas) + '...')

				//Pegando a linha atual e transformando em array
				cLinAtu := oArquivo:GetLine()
				aLinha  := Separa(cLinAtu, cSeparador)

				//Se houver posições no array
				If Len(aLinha) > 0

					//Transformando de caractere para numérico (exemplo '1.234,56' para 1234.56)
					aLinha[3] := StrTran(aLinha[3], '.' , '' )
					aLinha[3] := StrTran(aLinha[3], ',' , '.' )
					aLinha[3] := Val(aLinha[3])
					nValor    := aLinha[3]

					//Transformando os campos caractere, adicionando espaços a direita conforme tamanho do campo no dicionário
					cCGC     := AvKey(aLinha[1], 'A2_CGC' )
					cTipoOper := AvKey(aLinha[9], 'E2_XTPOPER')
					cTipoOper  := '0' + Alltrim(cTipoOper)

					//Verificando se o fornecedor existe
					BeginSql Alias cAliasSA2
						%noparser%

						SELECT
							A2_COD,
							A2_LOJA
						FROM
							%table:SA2% SA2 WITH (NOLOCK)
						WHERE
							A2_CGC = %exp:cCGC%
							AND SA2.D_E_L_E_T_ <> '*'
					EndSql

					(cAliasSA2)->(dbGoTop())

					cFornec  := AvKey((cAliasSA2)->A2_COD, 'A2_COD' )
					cForLoja := AvKey((cAliasSA2)->A2_LOJA, 'A2_LOJA' )
					cNomFor  := AvKey(aLinha[2], 'E2_NOMFOR' )
					cData    := AvKey(aLinha[8], 'E2_NUM' )
					cPrefix := AvKey(aLinha[10], 'E2_PREFIXO' )
					if cPrefix == ""
						//Se não tiver prefixo, pega o prefixo padrão
						cPrefix := AvKey("PIX", 'E2_PREFIXO' )
					EndIf
					cParcela := AvKey(" ", 'E2_PARCELA' )
					cTpNF    := AvKey("NF", 'E2_TIPO' )

					(cAliasSA2)->(DbCloseArea())

					DbSelectArea("SE2")
					SE2->(DbSetOrder(1))//E2_FILIAL + E2_PREFIXO + E2_NUM + E2_PARCELA + E2_TIPO + E2_FORNECE + E2_LOJA
					If !SE2->(MsSeek(xFilial('SE2')+cPrefix+cData+cParcela+cTpNF+cFornec+cForLoja))

						aDados      := {}
						aadd(aDados, {'E2_FILIAL' , xFilial("SE2")     , Nil})
						aadd(aDados, {'E2_PREFIXO', cPrefix            , Nil})
						aadd(aDados, {'E2_NUM'    , cData              , Nil})
						aadd(aDados, {'E2_TIPO'   , "NF"               , Nil})
						aadd(aDados, {'E2_NATUREZ', "FORN"             , Nil})
						aadd(aDados, {'E2_FORNECE', cFornec            , Nil})
						aadd(aDados, {'E2_LOJA'   , cForLoja           , Nil})
						aadd(aDados, {"E2_NOMFOR" , cNomFor            , Nil})
						aadd(aDados, {'E2_EMISSAO', Stod(cData)        , Nil})
						aadd(aDados, {'E2_VENCTO' , Stod(cData)        , Nil})
						aadd(aDados, {'E2_VENCREA', Stod(cData)        , Nil})
						aadd(aDados, {'E2_XTPOPER', cTipoOper          , Nil})
						aadd(aDados, {'E2_HIST'   , "Pagamento VIA PIX", Nil})
						aadd(aDados, {'E2_MOEDA'  , 1                  , Nil})
						aadd(aDados, {'E2_VALOR'  , nValor             , Nil})

						lMsErroAuto := .F.
						MsExecAuto({|x,y,z| FINA050(x,y,z)}, aDados,, 3) // 3 - Inclusao, 4 - Alteração, 5 - Exclusão

						//Se houve erro, gera o log
						If lMsErroAuto
							cPastaErro := '\x_logs\'
							cNomeErro  := 'erro_' + cAliasImp + '_lin_' + cValToChar(nLinhaAtu) + '_' + dToS(Date()) + '_' + StrTran(Time(), ':', '-') + '.txt'

							//Se a pasta de erro não existir, cria ela
							If ! ExistDir(cPastaErro)
								MakeDir(cPastaErro)
							EndIf

							//Pegando log do ExecAuto, percorrendo e incrementando o texto
							aLogErro := GetAutoGRLog()
							cTextoErro := ''
							For nLinhaErro := 1 To Len(aLogErro)
								cTextoErro += aLogErro[nLinhaErro] + CRLF
							Next

							//Criando o arquivo txt e incrementa o log
							MemoWrite(cPastaErro + cNomeErro, cTextoErro)
							cLog += '- Falha ao incluir registro, linha [' + cValToChar(nLinhaAtu) + '], arquivo de log em ' + cPastaErro + cNomeErro + CRLF
						Else
							cLog += '+ Sucesso no Execauto na linha ' + cValToChar(nLinhaAtu) + ';' + CRLF
						EndIf

					EndIf

				EndIf

			EndDo
			//End Transaction

			//Se tiver log, mostra ele
			If ! Empty(cLog)
				MemoWrite(cDirTmp + cArqLog, cLog)
				ShellExecute('OPEN', cArqLog, '', cDirTmp, 1)
			EndIf

		Else
			FWAlertError('Arquivo não tem conteúdo!', 'Atenção')
		EndIf

		//Fecha o arquivo
		oArquivo:Close()
	Else
		FWAlertError('Arquivo não pode ser aberto!', 'Atenção')
	EndIf

Return
