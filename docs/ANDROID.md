# Compilar y descargar Android en GitHub

El flujo [Android APK](https://github.com/hsalazar66/Boombeachhs/actions/workflows/android.yml) compila automáticamente cada cambio en `main`. También permite **Run workflow** desde GitHub.

1. Abre el enlace del flujo en el navegador e inicia sesión en GitHub.
2. Abre la ejecución más reciente y espera a que termine con éxito.
3. En **Artifacts**, descarga `archipielago-libre-android-N`.
4. Extrae el ZIP e instala `archipielago-libre-debug.apk` en un Android ARM/ARM64 con Android 7 o posterior. Autoriza la instalación desde tu navegador o administrador de archivos si Android lo solicita.
5. Abre el juego, crea un perfil y prueba una misión en modo avión.

El flujo ejecuta las pruebas de lógica antes de exportar, verifica la firma y comprueba que el manifiesto no solicite INTERNET ni ACCESS_NETWORK_STATE. Publica APK, huella SHA-256 y evidencias durante 30 días como artefacto de GitHub Actions. Esto no sustituye probar la instalación y el rendimiento en un dispositivo real.

**Firma temporal de pruebas:** la clave se genera en el runner y se elimina con él. Cada ejecución tiene una clave diferente. Android puede exigir desinstalar una compilación anterior para instalar la siguiente, perdiendo sus datos: exporta primero un respaldo desde Administración. Antes de distribuir versiones estables se debe configurar una clave duradera mediante secretos del repositorio, sin comprometerla en Git.

## Entorno fijado

- Godot 4.6.3 y plantillas oficiales de la misma versión.
- Java 17, Android SDK 36 y build-tools 36.1.0.
- Exportación directa APK, sin Gradle ni servicios de juego.
- Identificador `com.hsalazar66.archipielagolibre`, versión `0.1.0-dev`.
- `export_presets.cfg` incluye los datos JSON de balance y excluye pruebas y documentación.

## Exportación local

Instala esas herramientas y configura Java SDK Path, Android SDK Path y tu clave de depuración en Ajustes del editor → Exportación → Android. Instala las plantillas oficiales y ejecuta:

```sh
mkdir -p build
godot --headless --editor --path . --import --quit
godot --headless --path . --export-debug Android build/archipielago-libre-debug.apk
```

Documentación oficial: https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html

Las pruebas de aceptación en teléfono y conservación de datos al actualizar con una firma estable se describen en `ESTADO.md`.
