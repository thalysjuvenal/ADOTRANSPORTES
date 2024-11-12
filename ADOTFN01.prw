//Bibliotecas
#Include "Totvs.ch"

/*/{Protheus.doc} ADOTFN01
Importador Contas a Pagar
@author Thalys Augusto
@since 08/11/2024
@version 1.0
@type function
/*/
User Function ADOTFN01()
	Local aArea := FWGetArea()
	Local cDirIni := GetTempPath()
	Local cTipArq := 'Arquivos com separa��es (*.csv) | Arquivos texto (*.txt) | Todas extens�es (*.*)'
	Local cTitulo := 'Sele��o de Arquivos para Processamento'
	Local lSalvar := .F.
	Local cArqSel := ''

	//Se n�o estiver sendo executado via job
	If ! IsBlind()

		//Chama a fun��o para buscar arquivos
		cArqSel := tFileDialog(;
			cTipArq,;  // Filtragem de tipos de arquivos que ser�o selecionados
			cTitulo,;  // T�tulo da Janela para sele��o dos arquivos
			,;         // Compatibilidade
			cDirIni,;  // Diret�rio inicial da busca de arquivos
			lSalvar,;  // Se for .T., ser� uma Save Dialog, sen�o ser� Open Dialog
			;          // Se n�o passar par�metro, ir� pegar apenas 1 arquivo; Se for informado GETF_MULTISELECT ser� poss�vel pegar mais de 1 arquivo; Se for informado GETF_RETDIRECTORY ser� poss�vel selecionar o diret�rio
			)

		//Se tiver o arquivo selecionado e ele existir
		If ! Empty(cArqSel) .And. File(cArqSel)
			Processa({|| fImporta(cArqSel) }, 'Importando...')
		EndIf
	EndIf

	FWRestArea(aArea)
Return

/*/{Protheus.doc} fImporta
Fun��o que processa o arquivo e realiza a importa��o para o sistema
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
	Local lIgnor01         := FWAlertYesNo( 'Deseja ignorar a linha 1 do arquivo?' , 'Ignorar?' )
	Local cPastaErro       := '\x_logs\'
	Local cNomeErro        := ''
	Local cTextoErro       := ''
	Local cFornec          := ''
	Local cForLoja         := '01'
	Local aLogErro         := {}
	Local nLinhaErro       := 0
	Local lIncOk           := .F.
	//Vari�veis do ExecAuto
	Private cAlias         := GetNextAlias()
	Private aDados         := {}
	Private lMSHelpAuto    := .T.
	Private lAutoErrNoFile := .T.
	Private lMsErroAuto    := .F.
	//Vari�veis da Importa��o
	Private cAliasImp      := 'SA2'
	Private cSeparador     := ';'
	//Vari�veis da Importa��o em MVC
	Private aRotina        := FWLoadMenuDef( 'MATA020' )
	Private oModel         := Nil
	Private cIDAlias       := 'SA2MASTER' //Revise aqui o nome do AddFields da rotina

	//Abre as tabelas que ser�o usadas
	DbSelectArea(cAliasImp)
	(cAliasImp)->(DbSetOrder(1))
	(cAliasImp)->(DbGoTop())

	//Definindo o arquivo a ser lido
	oArquivo := FWFileReader():New(cArqSel)

	//Se o arquivo pode ser aberto
	If (oArquivo:Open())

		//Se n�o for fim do arquivo
		If ! (oArquivo:EoF())

			//Definindo o tamanho da r�gua
			aLinhas := oArquivo:GetAllLines()
			nTotLinhas := Len(aLinhas)
			ProcRegua(nTotLinhas)

			//M�todo GoTop n�o funciona (dependendo da vers�o da LIB), deve fechar e abrir novamente o arquivo
			oArquivo:Close()
			oArquivo := FWFileReader():New(cArqSel)
			oArquivo:Open()

			//Caso voc� queira, usar controle de transa��o, descomente a linha abaixo (e a do End Transaction), mas tem algumas rotinas que podem ser impactadas via ExecAuto
			//Begin Transaction

			//Enquanto tiver linhas
			While (oArquivo:HasLine())

				//Incrementa na tela a mensagem
				nLinhaAtu++
				IncProc('Analisando linha ' + cValToChar(nLinhaAtu) + ' de ' + cValToChar(nTotLinhas) + '...')

				//Pegando a linha atual e transformando em array
				cLinAtu := oArquivo:GetLine()
				aLinha  := Separa(cLinAtu, cSeparador)

				//Se estiver configurado para pular a linha 1, e for a linha 1
				If lIgnor01 .And. nLinhaAtu == 1
					Loop

					//Se houver posi��es no array
				ElseIf Len(aLinha) > 0

					//Transformando de caractere para num�rico (exemplo '1.234,56' para 1234.56)
					aLinha[3] := StrTran(aLinha[3], '.', '')
					aLinha[3] := StrTran(aLinha[3], ',', '.')
					aLinha[3] := Val(aLinha[3])

					//Transformando os campos caractere, adicionando espa�os a direita conforme tamanho do campo no dicion�rio
					cCGC     := AvKey(aLinha[1], 'A2_CGC' )
					cNome    := AvKey(aLinha[2], 'A2_NOME' )
					nValor   := aLinha[3]
					cCep     := AvKey(aLinha[4], 'A2_CEP' )
					cTipo    := AvKey(aLinha[5], 'A2_TIPO' )
					cTipPIX  := AvKey(aLinha[6], 'F72_TPCHV' )
					cChavPix := AvKey(aLinha[7], 'F72_CHVPIX' )
					cDataEmi := AvKey(aLinha[8], 'E2_EMISSAO' )

					//Utiliza HTTPGET para retornar os dados da Receita Federal
					cJson := HttpGet('https://viacep.com.br/ws/'+ cCep + '/json/', cGetParms, nTimeOut, aHeadStr, @cHeaderGet)

					//Transformando a string JSON em Objeto
					If FWJsonDeserialize(cJson,@oObjJson)
						cEnder  := oObjJson:logradouro
						cBairro := oObjJson:Bairro
						cMuni   := oObjJson:localidade
						cEstado := oObjJson:uf
						cCodMun := Substr(oObjJson:ibge,3)
					EndIf

					//Pegando o �ltimo c�digo do fornecedor conforme a query
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

					SA2->(DbSetOrder(3))
					If !SA2->(MsSeek(xFilial('SA2')+cCGC))

						aDados := {}
						aadd(aDados, {'A2_COD'    , cFornec           , Nil})
						aadd(aDados, {'A2_LOJA'   , cForLoja          , Nil})
						aadd(aDados, {'A2_CGC'    , cCGC              , Nil})
						aadd(aDados, {'A2_NOME'   , cNome             , Nil})
						aadd(aDados, {'A2_NREDUZ' , Substr(cNome,1,14), Nil})
						aadd(aDados, {'A2_END'    , cEnder            , Nil})
						aadd(aDados, {'A2_EST'    , cEstado           , Nil})
						aadd(aDados, {'A2_COD_MUN', cCodMun           , Nil})
						aadd(aDados, {'A2_MUN'    , cMuni             , Nil})
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

							//Se a pasta de erro n�o existir, cria ela
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
					Else
						cFornec := SA2->A2_COD
						cForLoja := SA2->A2_LOJA
						lIncOk := .T.
					EndIf

					If lIncOk
						U_F885MVC(cFornec,cForLoja, cTipPIX, cChavPix, cDataEmi, nValor)
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
			FWAlertError('Arquivo n�o tem conte�do!', 'Aten��o')
		EndIf

		//Fecha o arquivo
		oArquivo:Close()
	Else
		FWAlertError('Arquivo n�o pode ser aberto!', 'Aten��o')
	EndIf

Return


/*/{Protheus.doc} F885MVC

	inclus�o de chave PIX para fornecedor via execauto (MVC)

	@author      Thalys Augusto
	@example Exemplos
	@param   [Nome_do_Parametro],Tipo_do_Parametro,Descricao_do_Parametro
	@return  Especifica_o_retorno
	@table   Tabelas
	@since   08-11-2024
/*/
User Function F885MVC(cFornec As Character, cForLoja As Character, cTipoCHV As Character, cCodChvPIX As Character, cData as Character, nValor)

	//Local oModel      := Nil
	Local lOk := .F.

	DbSelectArea("F72")
	F72->(DbSetOrder(1)) //Codigo + Loja + Tipo Chv PIX + Chave PIX
	If !F72->(MsSeek(xFilial('F72')+cFornec+cForLoja))

		SoftLock('F72')
		RecLock("F72", .T.)
		F72->F72_COD := cFornec
		F72->F72_LOJA := cForLoja
		F72->F72_TPCHV := cTipoCHV
		F72->F72_CHVPIX := cCodChvPIX
		F72->F72_ACTIVE := '1'
		F72->(MsUnlock())

		lOk := .T.
	Else

		SoftLock("F72")
		RecLock("F72", .F.)
		F72->F72_COD := cFornec
		F72->F72_LOJA := cForLoja
		F72->F72_TPCHV := cTipoCHV
		F72->F72_CHVPIX := cCodChvPIX
		F72->F72_ACTIVE := '1'
		F72->(MsUnlock())

		lOk := .T.
	EndIf

	if lOk
		U_FIN050(cFornec, cForLoja, cData, nValor)
	Endif

Return


/*/{Protheus.doc} FIN050

	Inclui o titulo no contas a pagar

	@author      Thalys Augusto
	@example Exemplos
	@param   [Nome_do_Parametro],Tipo_do_Parametro,Descricao_do_Parametro
	@return  Especifica_o_retorno
	@table   Tabelas
	@since   08-11-2024
/*/
User Function FIN050(cFornec, cForLoja, cData, nValor)

	Local aVetSE2 := {}

	aadd(aVetSE2, {"E2_FILIAL" , FWxFilial("SE2")   , Nil})
	aadd(aVetSE2, {"E2_NUM"    , cData              , Nil})
	aadd(aVetSE2, {"E2_PREFIXO", "PIX"              , Nil})
	aadd(aVetSE2, {"E2_TIPO"   , "PX"               , Nil})
	aadd(aVetSE2, {"E2_NATUREZ", "PAGFOR"           , Nil})
	aadd(aVetSE2, {"E2_FORNECE", cFornec           , Nil})
	aadd(aVetSE2, {"E2_LOJA"   , cForLoja              , Nil})
	aadd(aVetSE2, {"E2_EMISSAO", Stod(cData)        , Nil})
	aadd(aVetSE2, {"E2_VENCTO" , Stod(cData)        , Nil})
	aadd(aVetSE2, {"E2_VENCREA", Stod(cData)        , Nil})
	aadd(aVetSE2, {"E2_VALOR"  , nValor             , Nil})
	aadd(aVetSE2, {"E2_HIST"   , "Pagamento VIA PIX", Nil})
	aadd(aVetSE2, {"E2_MOEDA"  , 1                  , Nil})

	//Inicia o controle de transa��o
	Begin Transaction
		//Chama a rotina autom�tica
		lMsErroAuto := .F.
		MSExecAuto({|x, y| FINA050(x,y)}, aVetSE2, 3)

		//Se houve erro, mostra o erro ao usu�rio e desarma a transa��o
		If lMsErroAuto
			MostraErro()
			DisarmTransaction()
		EndIf
		//Finaliza a transa��o
	End Transaction

Return Nil
