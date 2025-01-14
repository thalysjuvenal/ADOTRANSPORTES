//Bibliotecas
#Include "Totvs.ch"
#Include "FWMVCDEF.ch"

/*/{Protheus.doc} ADOTFN01

Importador de Fornecedores

@author Thalys Augusto
@since 08/11/2024
@version 1.0
@type function
/*/
User Function ADOTFN01()
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
@since 08/11/2024
@version 1.0
@type function
/*/
Static Function fImporta(cArqSel)
	Local cDirTmp          := GetTempPath()
	Local cArqLog          := 'importacao_' + dToS(Date()) + '_' + StrTran(Time(), ':' , '-' ) + '.log'
	Local nTotLinhas       := 0
	Local cLinAtu          := ''
	Local nLinhaAtu        := 0
	Local cJson            := ""
	Local cGetParms        := ""
	Local cHeaderGet       := ""
	Local nTimeOut         := 200
	Local aHeadStr         :={"Content-Type: application/json"}
	Local oObjJson         := Nil
	Local aLinha           := {}
	Local oArquivo
	Local cLog             := ''
	//Local lIgnor01         := FWAlertYesNo( 'Deseja ignorar a linha 1 do arquivo?' , 'Ignorar?' )
	Local cPastaErro       := '\x_logs\'
	Local cNomeErro        := ''
	Local cTextoErro       := ''
	Local cFornec          := ''
	Local cForLoja         := '01'
	Local aLogErro         := {}
	Local nLinhaErro       := 0
	Local lIncOk           := .F.
	Local lPixOK           := .F.
	//Variáveis do ExecAuto
	Private cAlias         := GetNextAlias()
	Private cAliasSA2      := GetNextAlias()
	Private aDados         := {}
	Private lMSHelpAuto    := .T.
	Private lAutoErrNoFile := .T.
	Private lMsErroAuto    := .F.
	//Variáveis da Importação
	Private cAliasImp      := 'SA2'
	Private cSeparador     := ';'
	//Variáveis da Importação em MVC
	Private aRotina        := FWLoadMenuDef( 'MATA020' )
	Private oModel         := Nil
	Private cIDAlias       := 'SA2MASTER' //Revise aqui o nome do AddFields da rotina

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
					aLinha[3] := StrTran(aLinha[3], '.', '')
					aLinha[3] := StrTran(aLinha[3], ',', '.')
					aLinha[3] := Val(aLinha[3])

					//Transformando os campos caractere, adicionando espaços a direita conforme tamanho do campo no dicionário
					cCGC := DelUTF8(aLinha[1])
					cCGC     := AvKey(cCGC, 'A2_CGC' )
					cNome    := AvKey(aLinha[2], 'A2_NOME' )
					cNome    := FWNoAccent(cNome)
					nValor   := aLinha[3]
					// Remove o traço do CEP, caso exista
					cCep     := StrTran(aLinha[4], "-", "")
					cCep     := AvKey(cCep, 'A2_CEP' )
					cTipo    := Alltrim(AvKey(aLinha[5], 'A2_TIPO' ))
					cTipPIX  := AvKey(aLinha[6], 'F72_TPCHV' )
					cTipPIX  := '0' + Alltrim(cTipPIX)
					if cTipPIX == "01"
						// Adiciona o prefixo +55 ao valor, assumindo que o valor original está em aLinha[7]
						cChavPix := "+55" + aLinha[7]
						cChavPix := AvKey(cChavPix, 'F72_CHVPIX')
					else
						cChavPix := AvKey(aLinha[7], 'F72_CHVPIX' )
					Endif

					Conout(cChavPix)

					// Inicializa valores padrão
					cEnder  := "RUA X"
					cBairro := "X"
					cMuni   := "SANTO ANDRE"
					cEstado := "SP"
					cCodMun := "47809"

					//Pegando o último código do fornecedor conforme a query
					BeginSql Alias cAlias
						%noparser%

						SELECT
							max(A2_COD) A2_COD
						FROM
							%table:SA2% SA2 WITH (NOLOCK)
						WHERE
							A2_COD NOT IN ('MUNIC', 'UNIAO', 'ISS', 'INSS')
					EndSql

					(cAlias)->(dbGoTop())

					cFornec := AvKey((cAlias)->A2_COD, 'A2_COD')
					cFornec := Soma1(cFornec)

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

					If (cAliasSA2)->A2_COD == "      "

						aDados := {}
						aadd(aDados, {'A2_COD'    , cFornec           , Nil})
						aadd(aDados, {'A2_LOJA'   , cForLoja          , Nil})
						aadd(aDados, {'A2_CGC'    , cCGC              , Nil})
						aadd(aDados, {'A2_NOME'   , Substr(cNome,1,60), Nil})
						aadd(aDados, {'A2_NREDUZ' , Substr(cNome,1,14), Nil})
						aadd(aDados, {'A2_END'    , cEnder            , Nil})
						aadd(aDados, {'A2_EST'    , cEstado           , Nil})
						aadd(aDados, {'A2_COD_MUN', cCodMun           , Nil})
						aadd(aDados, {'A2_MUN'    , cMuni             , Nil})
						aadd(aDados, {'A2_NATUREZ', "FORN"          , Nil})
						aadd(aDados, {'A2_PAIS'   , "105"             , Nil})
						aadd(aDados, {'A2_CODPAIS', "01058"           , Nil})
						aadd(aDados, {'A2_TPESSOA', "OS"              , Nil})
						aadd(aDados, {'A2_TIPO'   , cTipo             , Nil})

						lMsErroAuto := .F.
						oModel := FWLoadModel('MATA020')
						FWMVCRotAuto( ;
							oModel,; //Modelo
							cAliasImp,; //Alias
							MODEL_OPERATION_INSERT,; //Operacao
							{{cIDAlias, aDados}}; //Dados
							)

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
							lIncOk := .T.
						EndIf

						oModel:DeActivate()

						If lIncOk

							lPixOK := U_F885MVC(cFornec, cForLoja, cTipPIX, cChavPix, cNome)

							if lPixOK
								cLog += '+ Sucesso na Inclusão da Chave PIX: ' + cValToChar(nLinhaAtu) + ';' + CRLF
							else
								cLog += '+ Falha na Inclusão da Chave PIX: ' + cValToChar(nLinhaAtu) + ';' + CRLF
							Endif
						EndIf

					Endif
					(cAliasSA2)->(DbCloseArea())
				EndIf

				(cAlias)->(DbCloseArea())

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


/*/{Protheus.doc} F885MVC

	inclusão de chave PIX para fornecedor via execauto (MVC)

	@author      Thalys Augusto
	@example Exemplos
	@param   [Nome_do_Parametro],Tipo_do_Parametro,Descricao_do_Parametro
	@return  Especifica_o_retorno
	@table   Tabelas
	@since   08-11-2024
/*/
User Function F885MVC(cFornec As Character, cForLoja As Character, cTipoCHV As Character, cCodChvPIX As Character, cNomeFor as Character)

	Local oModel   := Nil
	Local lOk      := .F.
	Local aAreaF72 := GetArea()

	DbSelectArea("SA2")
	SA2->(DbSetOrder(1))
	If SA2->(DBSeek(xFilial("SA2") + cFornec + cForLoja))
		oModel := FwLoadModel ("FINA885")
		oModel:SetOperation(MODEL_OPERATION_INSERT)
		oModel:Activate()

		oModel:SetValue("FORMCAB","F72_FILIAL", xFilial("SA2"))
		oModel:SetValue("FORMCAB","F72_COD" , cFornec)
		oModel:SetValue("FORMCAB","F72_LOJA" , cForLoja)
		oModel:SetValue("FORMCAB","F72_NOME" , cNomeFor)

		oModel:SetValue("FORDETAIL", "F72_TPCHV" , cTipoCHV)
		oModel:SetValue("FORDETAIL", "F72_CHVPIX", cCodChvPIX)
		oModel:SetValue("FORDETAIL", "F72_ACTIVE", "1")

		If oModel:VldData()
			oModel:CommitData()
			lOk    := .T.
		Else
			VarInfo("",oModel:GetErrorMessage())
		EndIf

		oModel:DeActivate()
		oModel:Destroy()
		oModel := NIL
	EndiF

	SA2->(DbCloseArea())
	RestArea(aAreaF72)

Return lOk


/*/{Protheus.doc} DelUTF8

	inclusão de chave PIX para fornecedor via execauto (MVC)

	@author      Thalys Augusto
	@example Exemplos
	@param   [Nome_do_Parametro],Tipo_do_Parametro,Descricao_do_Parametro
	@return  Especifica_o_retorno
	@table   Tabelas
	@since   08-11-2024
/*/
Static Function DelUTF8(cString)

	if Len(cString) >= 3 .AND. Substr(cString,1,3) == Chr(239)+Chr(187)+Chr(191)
		cString := Substr(cString,4)
	endif

Return cString
