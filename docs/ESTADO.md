# Estado de requisitos

| ID | Estado | Alcance actual |
|---|---|---|
| RF-01 | Implementado | Cinco perfiles independientes; creación adicional con administración |
| RF-02 | Parcial | Consejos de tres pasos; falta tutorial interactivo con objetivos |
| RF-03 | Implementado | Cuadrícula, colisiones, límites y traslado por selección |
| RF-04 | Implementado | Costo, nivel y finalización temporal; construcción inicial instantánea |
| RF-05 | Implementado | Producción, capacidad y límite desconectado |
| RF-06 | Parcial | Entrenamiento inmediato y capacidad; faltan colas y gestión individual de lanchas |
| RF-07 | Implementado | Veinte misiones, desbloqueo secuencial |
| RF-08 | Implementado | Exploración sin costo |
| RF-09 | Prototipo | Movimiento A*, ataques y tres habilidades; faltan pruebas reales de jugabilidad |
| RF-10 | Implementado | Resultado único y recompensas no repetibles; falta prueba de cierre forzado en Android |
| RF-11 | Parcial | Fórmula de defensa visible, sin combate defensivo animado |
| RF-12 | Implementado | Escritura temporal, renombrado y respaldo; verificación en equipo pendiente |
| RF-13 | Prototipo | JSON validado y selector nativo; comprobar proveedor de documentos Android |
| RF-14 | Implementado | PIN, dificultad, reinicio, activar/desactivar, recursos de pruebas y auditoría |
| RF-15 | Parcial | Preferencias persistidas y fuente ajustable; audio, vibración y calidad sin efecto |

## Compilación verificada

GitHub Actions generó la primera APK el 3 de noviembre de 2026. Pasaron 64 comprobaciones de lógica, la verificación de firma APK v2/v3 y la ausencia de permisos de red en el manifiesto. La ejecución y su artefacto están disponibles en [Android APK](https://github.com/hsalazar66/Boombeachhs/actions/workflows/android.yml). Esto no verifica instalación, gestos ni rendimiento en un dispositivo.

## Validación pendiente para entrega Android

- Instalar la APK de prueba en el equipo objetivo y probar su arranque; exportación y firma automática ya verificadas.
- Jugar en modo avión, completar campaña y verificar balance.
- Probar gestos, tablet, respaldo por selector nativo y áreas seguras de pantalla.
- Cerrar el proceso durante mejora, pago y resultado; verificar recuperación.
- Verificar conservación de datos al actualizar con la misma clave de firma.
- Medir 30 FPS y memoria en sesión prolongada con límite de unidades definido.
- Ampliar pruebas de obstáculos complejos, distribución de objetivos y dificultad.

No se consideran comprobadas estas condiciones por pasar únicamente pruebas de lógica.
