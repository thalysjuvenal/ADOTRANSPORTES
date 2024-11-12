
# Importador de Contas a Pagar - ADOTFN01

## Descrição
Este projeto consiste em um importador de contas a pagar para o sistema Protheus, desenvolvido em ADVPL. Ele permite a seleção e importação de arquivos no formato CSV, validando e processando os dados para inclusão automática de títulos no sistema de contas a pagar, incluindo dados de fornecedores e chaves PIX.

## Autor
**Thalys Augusto Alves Juvenal**

## Tabela de Conteúdos
- [Importador de Contas a Pagar - ADOTFN01](#importador-de-contas-a-pagar---adotfn01)
  - [Descrição](#descrição)
  - [Autor](#autor)
  - [Tabela de Conteúdos](#tabela-de-conteúdos)
  - [Requisitos](#requisitos)
  - [Instalação](#instalação)
  - [Uso](#uso)
  - [Layout do Arquivo CSV](#layout-do-arquivo-csv)
  - [Descrição das Funções](#descrição-das-funções)
    - [`ADOTFN01`](#adotfn01)
    - [`fImporta`](#fimporta)
    - [`F885MVC`](#f885mvc)
    - [`FIN050`](#fin050)

## Requisitos
- **Protheus** com o módulo de contas a pagar.
- **ADVPL**: Linguagem para personalização no Protheus.
- Acesso à API `viacep.com.br` para consultas de CEP.

## Instalação
1. Clone o projeto no diretório de fontes do Protheus.
2. Compile os arquivos ADVPL no ambiente.
3. Verifique as permissões e configuracões necessárias para acessar a API de consulta de CEP.

## Uso
1. Acesse o módulo de contas a pagar e execute a função `ADOTFN01`.
2. Selecione o arquivo CSV conforme o layout especificado na próxima seção.
3. O sistema processará o arquivo e exibirá logs de sucesso ou erros.

## Layout do Arquivo CSV
O arquivo CSV deve estar no seguinte formato:

**Formato Geral**: `CPFCNPJ;NOME;VALOR;CEP;TIPO;TIPOCHAVEPIX;CHAVEPIX;DATATITULO`

| Campo         | Descrição                                                                                         | Formato                                                                                           | Exemplo               |
|---------------|---------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------|-----------------------|
| **CPFCNPJ**   | Número do CPF ou CNPJ do fornecedor, apenas números.                                              | Numérico                                                                                          | 12345678901           |
| **NOME**      | Nome do fornecedor.                                                                               | Texto, até 60 caracteres                                                                          | Fornecedor Exemplo    |
| **VALOR**     | Valor da transação.                                                                               | Numérico, separado por vírgula                                                                    | 1234,56               |
| **CEP**       | CEP do fornecedor, apenas números.                                                                | Numérico                                                                                          | 12345678              |
| **TIPO**      | Tipo de pessoa: `F` para física ou `J` para jurídica.                                             | Texto                                                                                            | F                     |
| **TIPOCHAVEPIX** | Tipo de chave PIX: `01` para telefone, `02` para email, `03` para CPF/CNPJ, `04` para chave aleatória. | Numérico                                                                                          | 01                    |
| **CHAVEPIX**  | Chave PIX do fornecedor, conforme o tipo definido.                                                | Texto (variável)                                                                                  | +5533991762759        |
| **DATATITULO**| Data do título, no formato `ANOMESDIA`.                                                           | Numérico                                                                                          | 20241112              |

**Exemplo de Linha**:
```csv
12345678901;Fornecedor Exemplo Ltda;1234,56;12345678;F;01;+5533991762759;20241112
```

## Descrição das Funções

### `ADOTFN01`
- **Descrição**: Função principal que inicia a importação do arquivo CSV para o sistema de contas a pagar.
- **Parâmetros**: Nenhum.
- **Fluxo**:
  1. Abre um diálogo para seleção de arquivos.
  2. Verifica se o arquivo selecionado existe.
  3. Chama a função `fImporta` para processar o arquivo.
- **Retorno**: Nenhum.

### `fImporta`
- **Descrição**: Processa o arquivo selecionado, realiza validações e insere dados no sistema.
- **Parâmetros**:
  - `cArqSel`: Caminho do arquivo selecionado.
- **Fluxo**:
  1. Abre o arquivo CSV e lê as linhas.
  2. Converte valores para o formato necessário, incluindo validações para CPF/CNPJ, valores numéricos, e chaves PIX.
  3. Realiza consultas à API de CEP (`viacep.com.br`) para completar dados de endereço.
  4. Insere ou atualiza dados de fornecedores e títulos no sistema.
  5. Gera logs para registros bem-sucedidos e erros de processamento.
- **Retorno**: Nenhum.

### `F885MVC`
- **Descrição**: Função que inclui ou atualiza a chave PIX para o fornecedor no sistema via ExecAuto.
- **Parâmetros**:
  - `cFornec`: Código do fornecedor.
  - `cForLoja`: Loja do fornecedor.
  - `cTipoCHV`: Tipo da chave PIX.
  - `cCodChvPIX`: Código da chave PIX.
  - `cData`: Data do título.
  - `nValor`: Valor da transação.
- **Fluxo**:
  1. Verifica a existência da chave PIX e realiza a inclusão ou atualização.
  2. Chama `FIN050` para incluir o título no contas a pagar.
- **Retorno**: Nenhum.

### `FIN050`
- **Descrição**: Inclui um título no módulo de contas a pagar.
- **Parâmetros**:
  - `cFornec`: Código do fornecedor.
  - `cForLoja`: Loja do fornecedor.
  - `cData`: Data do título.
  - `nValor`: Valor do título.
- **Fluxo**:
  1. Configura campos de título, como tipo, valor, data de emissão e vencimento.
  2. Realiza a inclusão automática no sistema.
  3. Gera log de erros se o título não puder ser incluído.
- **Retorno**: `Nil`.

**Nota**: Este projeto requer configurações específicas para acesso à API de consulta de CEP e permissões adequadas no ambiente do Protheus. Consulte a documentação do sistema para mais detalhes.
