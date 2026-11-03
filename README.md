# Archipiélago Libre · Boombeachhs

Prototipo de estrategia **sin conexión**, desarrollado en **Godot 4.6.3 / GDScript** para avanzar hacia una APK Android. Nombre, gráficos procedurales y contenido propios; no utiliza recursos de Supercell.

## APK Android

Abre [Android APK en GitHub Actions](https://github.com/hsalazar66/Boombeachhs/actions/workflows/android.yml), entra en la última ejecución correcta y descarga su artefacto. Extrae el ZIP para instalar la APK. Es una compilación de depuración con firma temporal; consulta [instrucciones y limitaciones](docs/ANDROID.md).

## Ejecutar

1. Instala Godot **4.6.3 estándar**, sin .NET.
2. Importa `project.godot` y ejecuta con F6/F5 (F5 para la escena principal).
3. Crea el primer perfil. Para crear perfiles adicionales, configura un PIN en Administración.
4. Construye, entrena tropas y explora la primera misión en Campaña.
5. En combate, selecciona una tropa y toca la playa para desembarcar. Destruye el CG con tus tropas y habilidades.

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/test_game.gd
```

## Implementado en este prototipo

- Hasta cinco perfiles locales con progreso independiente.
- Cuadrícula isométrica, construcción sin superposición, movimiento y mejoras temporizadas; cuartel de cinco niveles.
- Oro, madera y piedra, capacidad de almacenes y producción con límite de ocho horas sin conexión.
- Cuatro tipos de tropas, transporte limitado y entrenamiento inmediato.
- Veinte misiones secuenciales configurables, exploración gratuita y recompensas únicas.
- Combate separado de los gráficos: rutas A*, defensas, desembarco, energía, artillería, curación y bengala.
- Guardado atómico con respaldo, resolución de ataques interrumpidos como derrota e importación validada.
- PIN con PBKDF2-HMAC-SHA256, sal aleatoria, sesión temporal, bloqueo de intentos y registro administrativo.
- Simulación de defensa mediante fórmula visible, dificultad, recursos de prueba y reinicio con confirmación.
- Pruebas automatizadas y flujo de integración continua.

## Estado y límites

Es una **primera versión funcional**, no el cumplimiento completo de la especificación. El flujo Android APK genera una APK de pruebas descargable en GitHub Actions; consulta su última ejecución. La instalación y el rendimiento en un dispositivo Android aún requieren validación. Ver [estado de requisitos](docs/ESTADO.md) y [exportación Android](docs/ANDROID.md).

La defensa es una evaluación numérica, el tutorial son indicaciones y las misiones comparten un escenario parametrizado. Falta acabado artístico, sonido, vibración efectiva, ajuste real de calidad gráfica, tutorial interactivo guiado, investigación en armería, balance, validación táctil en móviles y medición de rendimiento. No hay multijugador ni servicios de red.

Los ajustes de audio, vibración y calidad se guardan, pero sus efectos no están implementados. La ampliación de interfaz ajusta el tamaño base de fuente; aún requiere revisión completa en móviles. El modo de edición mueve edificios mediante selección y destino, sin pulsación prolongada.

## Datos y privacidad

Partidas: `user://archipelago.json`, con copia `.bak`. Nunca se suben a GitHub. Los respaldos contienen todos los perfiles, registro y verificador del PIN; guárdalos en un lugar privado. Restaurar sustituye el conjunto de perfiles. El control administrativo local no protege contra modificaciones directas de los archivos. Cambiar la hora del dispositivo puede afectar la producción.

Configuración de economía, unidades y misiones: [`data/balance.json`](data/balance.json).
