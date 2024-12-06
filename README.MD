
# Importador de Fornecedores - Protheus

Este projeto contém as funções `ADOTFN01`, `fImporta` e `F885MVC`, desenvolvidas para o sistema Protheus com o objetivo de importar fornecedores a partir de arquivos CSV/TXT e realizar a inclusão de chaves PIX associadas a esses fornecedores. Abaixo, segue a documentação detalhada de cada função.

---

## **Função ADOTFN01**
Importador de Fornecedores.

- **Autor:** Thalys Augusto  
- **Data de Criação:** 08/11/2024  
- **Versão:** 1.0  
- **Tipo:** Function  

### **Descrição**
Esta função inicializa o processo de importação de fornecedores. Ela permite que o usuário selecione um arquivo para processamento (CSV ou TXT) e chama a função `fImporta` para realizar a importação.

### **Fluxo**
1. Abre um diálogo para seleção de arquivos.
2. Processa o arquivo selecionado, caso exista.
3. Encapsula a execução do processamento.

---

## **Função fImporta**
Função que processa o arquivo e realiza a importação para o sistema.

- **Autor:** Thalys Augusto  
- **Data de Criação:** 08/11/2024  
- **Versão:** 1.0  
- **Tipo:** Function  

### **Descrição**
Esta função realiza o processamento do arquivo selecionado, converte os dados em um formato adequado e realiza a inclusão dos fornecedores no sistema. Ela também registra logs detalhados de sucessos e falhas durante a importação.

### **Fluxo**
1. Lê o arquivo selecionado linha a linha.
2. Valida os dados e converte valores quando necessário.
3. Inclui os fornecedores utilizando a funcionalidade de automação (ExecAuto).
4. Realiza a inclusão de chaves PIX associadas aos fornecedores (chamando `F885MVC`).
5. Gera logs de erros e sucessos.

### **Recursos Utilizados**
- **Tabela:** SA2 (Fornecedores).
- **Separador:** `;`.
- **Logs:** Gerados no diretório `\x_logs\` com detalhes de erros por linha.

### **Parâmetros**
- **`cArqSel`**: Caminho do arquivo selecionado pelo usuário.

---

## **Função F885MVC**
Inclusão de chave PIX para fornecedor via ExecAuto (MVC).

- **Autor:** Thalys Augusto  
- **Data de Criação:** 08/11/2024  

### **Descrição**
Esta função utiliza a abordagem MVC para incluir uma chave PIX associada a um fornecedor específico. É chamada diretamente pela função `fImporta`.

### **Parâmetros**
- **`cFornec`** *(Character)*: Código do fornecedor.  
- **`cForLoja`** *(Character)*: Loja do fornecedor.  
- **`cTipoCHV`** *(Character)*: Tipo da chave PIX.  
- **`cCodChvPIX`** *(Character)*: Código da chave PIX.  
- **`cNomeFor`** *(Character)*: Nome do fornecedor.

### **Retorno**
- **`lOk`** *(Logical)*: Indica se a inclusão foi bem-sucedida.

### **Fluxo**
1. Verifica se o fornecedor existe na tabela `SA2`.
2. Carrega o modelo `FINA885` para inclusão da chave PIX.
3. Realiza a operação utilizando `SetValue` e `Activate`.
4. Retorna o status da operação.

---

## **Requisitos**
- Sistema Protheus.  
- Bibliotecas utilizadas:  
  - `Totvs.ch`  
  - `FWMVCDEF.ch`  

---

## **Como Utilizar**
1. Certifique-se de que as tabelas necessárias (`SA2`) estejam configuradas corretamente.  
2. Importe ou copie os fontes para o ambiente Protheus.  
3. Execute a função `ADOTFN01` para iniciar o processo de importação.  
4. Siga as mensagens do sistema para selecionar o arquivo desejado.

---

## **Observações**
- O sistema solicita ao usuário se deve ignorar a primeira linha do arquivo.  
- Logs de erro são gerados automaticamente em caso de falhas.  
- Os fornecedores duplicados são ignorados durante o processo.

---