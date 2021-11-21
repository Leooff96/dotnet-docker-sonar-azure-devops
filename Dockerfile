FROM mcr.microsoft.com/dotnet/aspnet:5.0-buster-slim AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:5.0-buster-slim AS build

LABEL artifacts=true

ARG SONAR_TOKEN
ARG SONARQUBE_SCANNER_PARAMS

ENV SONARQUBE_SCANNER_PARAMS=${SONARQUBE_SCANNER_PARAMS}
ENV DOTNET_SONARSCANNER_VERSION=5.3.1
ENV DOTNET_REPORT_VERSION=4.8.12

WORKDIR /src

## Install Java
RUN apt-get update && apt-get install -y openjdk-11-jre

## Install sonarscanner
RUN dotnet tool install --global dotnet-sonarscanner --version $DOTNET_SONARSCANNER_VERSION

## Install report generator
RUN dotnet tool install --global dotnet-reportgenerator-globaltool --version $DOTNET_REPORT_VERSION

## Set the dotnet tools folder in the PATH env variable
ENV PATH="${PATH}:/root/.dotnet/tools"

COPY *.sln ./
COPY ["ExampleApi/Example.Api.csproj", "ExampleApi/"]
COPY ["Example.Api.Tests/Example.Api.Tests.csproj", "Example.Api.Tests/"]

## Restore Solution
RUN dotnet restore
COPY . .

## Start scanner
RUN dotnet sonarscanner begin /key:"devanywhere_PublicProjectsLeooff" /o:"devanywhere" /d:sonar.login="${SONAR_TOKEN}" 

## Run Build
RUN dotnet build "/src/ExampleApi/Example.Api.csproj" -c Release -o /app/build

## Run Tests
RUN dotnet test "/src/Example.Api.Tests/Example.Api.Tests.csproj" --logger "trx;LogFileName=testresults.trx" --collect:"XPlat Code Coverage" --results-directory "/TestResults/"

## Run Generate Report
RUN reportgenerator "-reports:/TestResults/*/coverage.cobertura.xml" "-targetdir:/TestResults/coverage" "-reporttypes:SonarQube"

## Finish Scanner
RUN dotnet sonarscanner end /d:sonar.login="${SONAR_TOKEN}"

FROM build AS publish
RUN dotnet publish "/src/ExampleApi/Example.Api.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Example.Api.dll"]