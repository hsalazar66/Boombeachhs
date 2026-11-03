# Exportación Android

Motor fijado: Godot **4.6.3 estándar**. Usar las plantillas de exportación de esa misma versión.

1. Instalar OpenJDK 17 y Android SDK siguiendo la documentación de exportación Android de Godot 4.6: https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html
2. En Ajustes del editor → Exportación → Android, configurar Java SDK Path y Android SDK Path.
3. Instalar las plantillas 4.6.3 desde Administrar plantillas de exportación.
4. Proyecto → Exportar → Añadir Android. Identificador sugerido: `com.hsalazar66.archipielagolibre`.
5. Orientación horizontal; exportación APK; compatibilidad ARM64. Desactivar todos los permisos de red. No usar depuración remota al validar modo avión.
6. Exportar una APK de depuración para pruebas. Para distribución, configurar una clave de firma propia fuera del repositorio y mantenerla para todas las actualizaciones.
7. Instalar en el dispositivo, activar modo avión y ejecutar el plan de `ESTADO.md`.

No se incluye una clave de firma ni se declara una APK lista. La infraestructura Android no está preparada en este entorno y la compilación está pendiente. No comprometer contraseñas, claves ni `export_credentials.cfg` en Git.
