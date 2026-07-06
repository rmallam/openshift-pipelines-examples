## Stage 1: build
FROM registry.access.redhat.com/ubi9/openjdk-17:1.20 AS build
USER 0
WORKDIR /workspace
COPY pom.xml .
COPY src ./src
RUN mvn -B -q package -DskipTests

## Stage 2: runtime
FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:1.20
WORKDIR /deployments
COPY --from=build /workspace/target/quarkus-app/lib/ /deployments/lib/
COPY --from=build /workspace/target/quarkus-app/*.jar /deployments/
COPY --from=build /workspace/target/quarkus-app/app/ /deployments/app/
COPY --from=build /workspace/target/quarkus-app/quarkus/ /deployments/quarkus/
EXPOSE 8080
USER 185
ENTRYPOINT ["java", "-jar", "/deployments/quarkus-run.jar"]
