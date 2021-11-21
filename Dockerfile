FROM mcr.microsoft.com/dotnet/aspnet:5.0-buster-slim AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:5.0-buster-slim AS build

LABEL artifacts=true

ARG SONAR_TOKEN

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

## Restore Solution
RUN dotnet restore
COPY . .

## Start scanner
RUN dotnet sonarscanner begin /d:sonar.login="${SONAR_TOKEN}"

## Run Build
WORKDIR "/src/ExampleApi"
RUN dotnet build "Example.Api.csproj" -c Release -o /app/build

## Run Tests
RUN dotnet test src/Example.Api.Tests/*.Tests.csproj --logger "trx;LogFileName=testresults.trx" --collect:"XPlat Code Coverage" --results-directory "/TestResults/"

## Run Generate Report
RUN reportgenerator "-reports:/TestResults/*/coverage.cobertura.xml" "-targetdir:/TestResults/coverage" "-reporttypes:SonarQube"

## Finish Scanner
RUN dotnet sonarscanner end /d:sonar.login="${SONAR_TOKEN}"

FROM build AS publish
RUN dotnet publish "Example.Api.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Example.Api.dll"]