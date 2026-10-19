# SonaPlay — inventario de funcionalidades (heredado de V1-Demo)

Especificación para V2. La capa de datos/dominio ya está portada; la UI se rehace desde cero.

## Inicio y sistema
- Pantalla de permiso de audio (abre ajustes si se deniega)
- Actualización forzada (Firebase Remote Config + diálogo con enlace) — `core/services/update_service.dart`
- Crashlytics; orientación vertical; barra de estado transparente

## Biblioteca (4 pestañas)
- Canciones: lista completa, "Reproducir todo", "Shuffle Play"
- Playlists: crear, renombrar, borrar, detalle, collage de carátulas
- Favoritos
- Carpetas + detalle de carpeta
- Búsqueda por texto con estado vacío
- Filtros por artista y álbum
- Ordenar por título, artista, álbum, duración, fecha (asc/desc) — `SortOption`
- Escaneo: caché Hive primero, sincronización en segundo plano (consulta nativa a MediaStore fuera del hilo de UI, canal `sonaplay/media`)

## Menú de opciones de canción
Editar metadatos · agregar a playlist · compartir · velocidad · tono de llamada · temporizador para dormir · ocultar · eliminar (papelera)

## Multiselección (pulsación larga)
Seleccionar todo con contador · agregar a playlist · reproducir a continuación · compartir · ocultar · eliminar (con confirmación)

## Reproductor
- Pantalla completa: carátula, título/artista, barra de progreso arrastrable, anterior/play/siguiente
- Shuffle; repetir (off / todas / una)
- Cola, compartir, favorito; ecualizador (en V1 era un botón vacío)
- Color de fondo según la carátula
- Mini reproductor; pantalla de cola actual
- Persistencia de shuffle, repeat, orden y filtros

## Segundo plano
- Servicio en primer plano con notificación y carátula; acciones shuffle/repeat/favorito
- Auriculares: 1 toque play/pausa, 2 siguiente, 3 anterior
- Adelantar/retroceder 10 s

## Herramientas
- Editor de metadatos: título, artista, álbum, carátula de galería (solo dentro de la app)
- Recortador de tonos: forma de onda, rango, guardar como tono (canal `sonaplay/ringtone`)

## Ajustes
- Archivos ocultos (restaurar) · Eliminado recientemente (restaurar + **eliminar definitivamente**: borra el archivo con confirmación del sistema — `TrashPurger`, hecho en V2)
- Guardados sin UI en V1: modo OLED, intensidad de cristal, duración mínima, calidad de carátula, color de acento

## Decisiones de diseño V2 (2026-10-18)
- Estilo: oscuro (casi negro, apto OLED) con acento tomado de la carátula que suena; sin glassmorphism pesado
- Ecualizador: se implementa con `AndroidEqualizer` de just_audio (bandas + presets)
- Ajustes: solo los útiles (duración mínima y lo que el estilo necesite); OLED, intensidad de cristal, calidad de carátula y color de acento se eliminan

## Pendiente en V2
- Rediseño UI/UX completo
- Sin probar en dispositivo: carátula desde la galería, borrado en Android 9 y 10
- Notificación: Android 13+ solo muestra 2 botones extra (favorito y aleatorio); repetir queda fuera
