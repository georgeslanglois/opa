@echo off

REM #Script Name:	opa #
REM #Version:		1.0 #
REM #Description:	Conecta o usuário ao servidor apenas com informação de hostname ou IP buscando dados no portal PGS #
REM #Created_by:	Georges Langlois #
REM #Updated_by:	Nome Analista #
REM #Date_modified:	03 Nov 2023 #

setlocal enabledelayedexpansion

REM Comando para tratar caracteres latinos (SALVAR ARQUIVO em UTF-8 sem BOM)
@chcp 65001>nul

set "local_do_script=%~d0%~p0"

cd /d %HOMEDRIVE%%HOMEPATH%

REM Define e verifica se arquivo de configuração do usuário existe
set "ini_file=%HOMEDRIVE%%HOMEPATH%\opa_%USERNAME%.ini"
if not exist "%ini_file%" goto :CRIAR_INI
echo.
echo Arquivo .ini encontrado: %ini_file%

REM URL com informações dos servidores
set "url=https://github.com/georgeslanglois/opa/blob/main/opa.bat"


REM Lê o arquivo opa_usuario.ini e atribui os valores às variáveis correspondentes
for /f "tokens=1,* delims==" %%A in (%ini_file%) do (
    set %%A=%%B
)
echo.
echo Olá !nome!
echo Carregando...


REM Verifica se o usuário informou algo
if "%1"=="" (
    echo.
    echo Nenhum servidor foi informado^^!
    echo.
    echo Pressione enter para sair.
    pause >nul
    exit
)
set "servidor=%~1"

REM Verifica se há um segundo parametro de entrada que será tratado como usuario
if not "%2"=="" (
    set "cusuario=%2" 
    echo.
    echo Usuário definido manualmente: !cusuario!
    echo.
)


REM Obtém o conteúdo da URL com informações de servidores e salva em um arquivo temporário
curl -s "%url%" > temp.txt

REM Verifica se o valor informado é um IP e define se a coluna buscada nas informações da PGS será de IP %%b ou servidor %%a
echo %servidor% | findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*"
if %errorlevel% equ 0 (
    echo.
    REM Se for um IP, 
    set coluna_processa=%%b
    echo Endereço IP informado: %servidor%
) else (
    echo.
    set coluna_processa=%%a
    echo HOSTNAME informado: %servidor%
)

:PROCESSA_SERVIDOR
for /f "tokens=1-6 delims=;" %%a in (temp.txt) do (
    REM A variavel coluna_processa aqui fará referência às strings literais "%%a" ou "%%b" (definido no if anterior) dependendo se for ip ou não. Sendo que "%%a" faz referência a primeira coluna de temp.txt que tem hostname e "%%b", à segunda coluna que tem o IP
    if /I "%coluna_processa%"=="%servidor%" (
        set "hostname=%%a"
        set "ip=%%b"
        set "dominio=%%d"
        set "so=%%e"
        
        REM Se a informação de dominio for DOMINIO VAZIO, define dc00
        if !dominio!=="DOMINIO VAZIO" (
            echo.
            echo Servidor encontrado com DOMINIO VAZIO^^! Definindo DC00 experimentalmente.
            set "dominio=prodesp-dc00"
        )
       
        REM Define variavel de SO e verifica se é Windows
        echo !so! | findstr /i "windows" >nul
        if !errorlevel! equ 0 (
            set "so2=windows"
        ) else (
            REM Verifica se a variável SO se contém Sistemas Operacionais conectáveis
            echo !so! | findstr /i "linux centos ubuntu exadata" >nul
            if !errorlevel! equ 0 (
                set "so2=linux"
            ) else (
                echo ATENÇÃO^^! Sistema Operacional desconhecido para conexão = !so!
                echo Pressione enter para sair.
                pause >nul
                exit
            )
        )
        echo.
        goto :CONECTAR_SERVIDOR
    )
)
echo.
echo Servidor [%servidor%] não encontrado na base da PGS^^!
goto :CONEXAO_ALTERNATIVA

:CONEXAO_ALTERNATIVA
echo.
choice /C 123 /N /M "Digite [1] para tentar conexão Windows, [2] para Linux ou [3] para sair.."
set opc=!errorlevel!
if !opc! EQU 1 (
    start "" C:\Windows\system32\mstsc.exe /v:%servidor% !mstsc_size!
)
if !opc! EQU 2 (
    if "!aplicativo!"=="2" (
        start "" "!moba_local!" -newtab "ssh "!cusuario!@%servidor%"
    ) else (
        start "" "!winscp_local!" scp://!cusuario!:!cpass!@%servidor%:22
    )
)
REM Grava arquivo com os servidores que não conectaram. *os espaços são tabulações
echo %DATE%	%TIME%	%servidor%	!cusuario!>> "%local_do_script%\opa_servidores.txt"
echo.
REM echo Pressione enter para sair
REM pause >nul
exit

:CONECTAR_SERVIDOR
echo.
echo =========== INICIANDO CONEXÃO ===========
echo Hostname: !hostname!
echo IP: !ip!
echo Sistema Operacional: !so!
echo Domínio: !dominio!
echo Usuario: !cusuario!
echo.
echo *Para acessar com outro usuário utilize: "opa [servidor] [usuário]"
if "!cpass!"=="senha" (
    echo *Nenhuma senha foi definida pelo usuário no arquivo .ini
) else (
    echo *Utilizando senha definida pelo usuário no arquivo .ini
)
echo =========================================
echo. 
REM Verifique se o servidor é windows ou linux
if "!so2!"=="windows" (
    echo.
    echo Iniciando Área de Trabalho Remota - MSTSC...
    echo. 
    REM *Modificado de IP para HOSTNAME em 26/03/24 para aparecer o nome na tela do MSTSC
    cmdkey /generic:"!hostname!" /user:"%dominio%\!cusuario!" /pass:"!cpass!"
    start "" C:\Windows\system32\mstsc.exe /v:!hostname! !mstsc_size!
) else if "!so2!"=="linux" (
    REM Se o servidor é linux, ele fornece opção de logar como root
    choice /C SN /N /M "Servidor LINUX. Deseja conectar com usuário ROOT? Pressione [S] para Sim ou [N] para Não..."
    set opc=!errorlevel!
    if !opc! EQU 1 (
        set cusuario=root
        echo.
        echo Usuário Root definido para conexão.
        echo.
    )

    REM verifica se o usuário escolheu MOBA ou WinSCP no arquivo de configuração .ini e abre o aplicativo.
    if "!aplicativo!"=="2" (
        echo.
        echo Iniciando MOBA...
        echo. 
        start "" "!moba_local!" -newtab "ssh "!cusuario!@!ip!"
    ) else (
        echo.
        echo Iniciando WinSCP...
        echo. 
        start "" "!winscp_local!" scp://!cusuario!:!cpass!@!ip!:22
    )
) else (
    echo Sistema operacional desconhecido: !so!
)

endlocal
exit

:CRIAR_INI
REM Criar variavel com nome do usuario
set TNAME="net user %USERNAME% /domain| FIND /I "Nome Completo""

REM FOR /F "tokens=3,4 delims=, " %%A IN ('%TNAME%') DO SET DNAME=%%B
FOR /F "tokens=2*" %%A IN ('%TNAME%') DO SET DNAME=%%B
REM Obter o usuario (obtem de "whoami /upn" que traz e-mail)
for /f "tokens=1 delims=@" %%a in ('whoami /upn') do (
    set "cusuario=%%a"
)
echo.
echo Olá %DNAME%
echo.
echo Preencha o arquivo "%ini_file%" para utilizar a bat.
echo Caso o arquivo não seja modificado, os parametros padrão serão utilizados.
REM Cria o arquivo ini com alguns dados do usuario e parametros padrão
(
echo "nome=!DNAME!"
echo.
echo \\ CONFIRA SE SEU USUÁRIO DOS DOMINIOS DO DC ESTÁ CORRETO
echo "cusuario=!cusuario!"
echo.
echo \\ PREENCHA ABAIXO SE DESEJAR UTILIZAR UMA SENHA ÚNICA
echo "cpass=senha"
echo.
echo \\ INDIQUE QUAL APLICATIVO UTILIZA: 1 para WinSCP / 2 para MOBA
echo "aplicativo=1"
echo.
echo \\ SUBSTITUA O CAMINHO ABAIXO PELO LOCAL DO SEU EXECUTÁVEL DO WINSCP OU MATENHA O PADRÃO. ATENÇÃO, O WINSCP DEVE ESTAR ATUALIZADO.
echo "winscp_local=T:\Diretorio\WinSCP\WinSCP.exe"
echo.
echo \\ SUBSTITUA O CAMINHO ABAIXO PELO LOCAL DO SEU EXECUTÁVEL DO MOBA OU MATENHA O PADRÃO
echo "moba_local=T:\Diretorio\MobaXterm\MobaXterm_Personal_21.4.exe"
echo.
echo \\ TAMANHO DA TELA DO MSTSC Area de Trabalho Remota
echo "mstsc_size=/w:1600 /h:900"
) > "%ini_file%"
REM Abre o arquivo ini para edição
%ini_file%
echo.
echo Pressione enter para sair
pause >nul
exit
