name := "MaritimeTracking"

version := "1.0"

scalaVersion := "2.12.18"

// Résolveurs
resolvers ++= Seq(
  "Maven Central" at "https://repo1.maven.org/maven2/",
  "Confluent" at "https://packages.confluent.io/maven/"
)

libraryDependencies ++= Seq(
  // Spark Core (sans "provided" pour le producer)
  "org.apache.spark" %% "spark-core" % "3.5.0",
  "org.apache.spark" %% "spark-sql" % "3.5.0",
  "org.apache.spark" %% "spark-streaming" % "3.5.0",
  
  // Kafka
  "org.apache.spark" %% "spark-streaming-kafka-0-10" % "3.5.0",
  "org.apache.kafka" % "kafka-clients" % "3.5.0",
  
  // Logging
  "org.slf4j" % "slf4j-api" % "2.0.9",
  "org.slf4j" % "slf4j-simple" % "2.0.9"
)

// Options de compilation
scalacOptions ++= Seq(
  "-deprecation",
  "-feature",
  "-unchecked",
  "-language:postfixOps"
)

// Configuration Assembly
assembly / assemblyJarName := "maritime-tracking.jar"

assembly / assemblyMergeStrategy := {
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case "reference.conf" => MergeStrategy.concat
  case x if x.endsWith(".proto") => MergeStrategy.rename
  case x if x.contains("slf4j") => MergeStrategy.first
  case _ => MergeStrategy.first
}

// INCLURE Scala dans le JAR (pour pouvoir exécuter standalone)
assembly / assemblyOption := (assembly / assemblyOption).value.withIncludeScala(true)