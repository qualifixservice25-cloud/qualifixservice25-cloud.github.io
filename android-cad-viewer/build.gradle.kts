// Build di root intenzionalmente vuota: ogni modulo dichiara i propri plugin tramite il
// version catalog (gradle/libs.versions.toml). Cosi' il plugin Android non viene risolto
// quando si compila o si testa il solo modulo :core su una JVM senza SDK Android.
