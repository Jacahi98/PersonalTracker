# 💰 Control de Gastos - Flutter App

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/sqlite-%2307405e.svg?style=for-the-badge&logo=sqlite&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=ios&logoColor=white)

Una aplicación móvil moderna, rápida y eficiente para el seguimiento de finanzas personales. Permite registrar gastos, visualizar estadísticas detalladas y exportar datos, todo funcionando de manera local y segura en tu dispositivo.

## ✨ Características Principales

* **⚡ Rendimiento Nativo:** Base de datos local **SQLite** (`sqflite`) para un manejo instantáneo de miles de registros.
* **📊 Análisis Visual:** Gráficas de barras interactivas con degradados (`fl_chart`) para visualizar gastos por Semana, Mes, Año o Rango Personalizado.
* **📂 Organización:** Categorización de gastos con iconos y colores distintivos (Comida, Transporte, Ocio, etc.).
* **📥 Exportación de Datos:** Generación de reportes en **Excel (.csv)** y función de compartir nativa (WhatsApp, Email, AirDrop, Archivos).
* **📅 Calendario Inteligente:** Filtros de fecha avanzados y selector de rangos personalizado con soporte completo en español.
* **🎨 UI/UX Moderna:** Diseño limpio basado en Material 3, tarjetas con sombras suaves y feedback visual.

## 🛠️ Tecnologías y Librerías

Este proyecto utiliza las siguientes dependencias clave:

* `sqflite` & `path`: Persistencia de datos local robusta.
* `fl_chart`: Gráficas estadísticas avanzadas.
* `share_plus` & `path_provider`: Gestión de archivos y sistema de compartir nativo.
* `csv`: Generación de hojas de cálculo.
* `intl` & `flutter_localizations`: Formato de fechas y monedas localizados (Español).

## 🚀 Instalación y Ejecución

Sigue estos pasos para correr el proyecto en tu máquina local:

1.  **Clonar el repositorio:**
    ```bash
    git clone [https://github.com/tu-usuario/app-control-gastos.git](https://github.com/tu-usuario/app-control-gastos.git)
    cd app-control-gastos
    ```

2.  **Instalar dependencias:**
    ```bash
    flutter pub get
    ```

3.  **Configuración para iOS (Solo Mac):**
    ```bash
    cd ios
    pod install
    cd ..
    ```

4.  **Ejecutar la App:**
    ```bash
    flutter run
    ```

## 📂 Estructura del Proyecto
