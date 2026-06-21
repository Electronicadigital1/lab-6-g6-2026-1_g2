[![Open in Visual Studio Code](https://classroom.github.com/assets/open-in-vscode-2e0aaae1b6195c2367325f4f02e2d04e9abb55f0b24a779b69b11b9e10269abc.svg)](https://classroom.github.com/online_ide?assignment_repo_id=24121059&assignment_repo_type=AssignmentRepo)
# Informe de Laboratorio 04: Visualización usando pantalla LCD 16x2 en modo paralelo

## Integrantes

**Juliana Zúñiga Cruz - 1032800049** \
**Karen Gissell Buitrago Osorio - 1077112461** \
**Nicolas Ramírez Gonzalez -  1023371323**

Indice:

1. [Diseño implementado](#diseño-implementado)
2. [Simulaciones](#simulaciones)
3. [Implementación](#implementación)
4. [Conclusiones](#conclusiones)
5. [Referencias](#referencias)

Este laboratorio consistió en el diseño, simulación e implementación en hardware de un sistema de visualización alfanumérica sobre una pantalla LCD 16x2 (controlador HD44780), controlada mediante una Máquina de Estados Finitos (FSM) descrita en Verilog sobre una FPGA Intel/Altera Cyclone IV.

El proyecto se dividió en dos fases:

1. **Fase estática (módulo `LCD`):** secuencia de inicialización del controlador y escritura de un mensaje fijo en las dos filas de la pantalla (`"5 en este"` en la fila 1 y `"laboratorio"` en la fila 2). La FSM ejecuta la secuencia una sola vez y queda detenida en el estado final.

2. **Fase dinámica (módulo `lcd_parte2`):** se reemplaza el mensaje fijo por dos valores numéricos de entrada (`entrada_a` y `entrada_b`, cada uno de 4 bits, rango 0–15, tomados de un banco de 8 switches físicos). Cada valor se convierte a su representación decimal en ASCII y se acompaña de una etiqueta de clasificación calculada por comparación de magnitud:

   | Rango de entrada | Etiqueta mostrada |
   |---|---|
   | 0 – 4 | `BAJO` |
   | 5 – 10 | `MEDI` |
   | 11 – 15 | `ALTO` |

   La etiqueta se limita a 4 caracteres (columnas 11 a 14 de cada fila) por restricción de espacio en la pantalla; por eso el rango medio se abrevia `MEDI` en lugar de `MEDIO`. El formato final de cada fila es:

   ```
   Temp A: DD XXXX
   Temp B: DD XXXX
   ```

   donde `DD` son las decenas/unidades del valor (00–15) y `XXXX` es `BAJO`, `MEDI` o `ALTO`. A diferencia de la fase estática, esta FSM no se detiene: al terminar de escribir la fila 2 regresa al inicio de la fila 1 (comando `0x80`), generando un refresco continuo que permite que el valor mostrado siga a las entradas físicas en tiempo real.

   Un punto importante al revisar el código: la secuencia de inicialización (`0x30`, `0x30`, `0x30`, `0x38`) corresponde al protocolo estándar del HD44780 para **interfaz de 8 bits** (`0x38` = Function Set con `DL=1`), no de 4 bits. El bus de datos `dat` se maneja como un byte completo por cada carácter/comando, sin partir en nibbles. Esto se corrigió respecto a la descripción inicial del informe.

---

## 2. Diagramas

### 2.1 Unidad de Control (FSM)

La FSM gestiona la inicialización del controlador y la escritura secuencial de cada carácter. El siguiente diagrama resume la versión dinámica (`lcd_parte2`), agrupando los 40 estados individuales del código en bloques funcionales:

```mermaid
stateDiagram-v2
    [*] --> INIT
    INIT --> FILA1_TXT : 8 comandos de inicializacion (Function Set 8 bits, Display ON, Clear, Entry Mode)
    FILA1_TXT --> FILA1_DIG : Escribe texto fijo "Temp A: " (8 caracteres)
    FILA1_DIG --> FILA1_ETQ : Escribe decenas y unidades de entrada_a
    FILA1_ETQ --> CAMBIO_FILA2 : Escribe etiqueta BAJO / MEDI / ALTO
    CAMBIO_FILA2 --> FILA2_TXT : Comando 0xC0 (direccion DDRAM fila 2)
    FILA2_TXT --> FILA2_DIG : Escribe texto fijo "Temp B: " (8 caracteres)
    FILA2_DIG --> FILA2_ETQ : Escribe decenas y unidades de entrada_b
    FILA2_ETQ --> FILA1_TXT : Comando 0x80 (DDRAM fila 1, refresco continuo)
```

En la fase estática (módulo `LCD`) la estructura es idéntica hasta el final de la fila 2, pero en lugar de regresar a `FILA1_TXT` la FSM cae en un estado `default` que mantiene `busy = 0` indefinidamente, dejando el mensaje fijo en pantalla.

### 2.2 Arquitectura completa del sistema

El módulo `lcd_parte2` combina tres bloques: lógica combinacional de conversión/clasificación, la FSM secuencial de control, y la generación de temporización para las señales físicas hacia la LCD.

```mermaid
flowchart LR
    CLK["clk (50 MHz)"] --> FSM
    SWA["entrada_a (4 bits, 0-15)"] --> CONV["Conversor BIN -> ASCII<br/>+ Clasificador de rango<br/>(bloque combinacional)"]
    SWB["entrada_b (4 bits, 0-15)"] --> CONV
    CONV -->|digitos + etiqueta ASCII| FSM["FSM secuencial<br/>(control + temporizacion:<br/>delay_cnt, en_cnt)"]
    FSM -->|RS| LCD["LCD 16x2<br/>controlador HD44780"]
    FSM -->|RW = 0| LCD
    FSM -->|E, pulso de 25 us| LCD
    FSM -->|D0-D7| LCD
```

El bloque combinacional (`always @(*)`) calcula, para cada entrada, las cifras decimal/unidad (`/10`, `%10`, sumando `8'h30`) y la etiqueta de 4 caracteres mediante comparaciones `<= 4`, `<= 10`. Estos valores quedan disponibles permanentemente; es la FSM la que decide en qué estado tomarlos y enviarlos a la LCD, junto con el bit `RS` correspondiente (comando o dato) empaquetado en `lcd_cmd[8]`.

---

## 3. Simulaciones

Para validar el comportamiento temporal y lógico de la FSM antes de programar la FPGA, se ejecutó el *testbench* sobre los módulos `LCD` y `lcd_parte2` en ModelSim/Questa.

### 3.1 Inicialización de la LCD

* ![Simulación Inicialización](ruta_a_tu_imagen_sim_init.png)
* **Análisis:** durante los estados `0` a `7`, `RS` permanece en `0` (modo comando) mientras se envían los comandos de configuración (`0x30 ×3`, `0x38`, `0x08`, `0x01`, `0x06`, `0x0C`). Cada comando se mantiene estable en `dat` durante el tiempo de espera definido por `wait_time` (`DELAY_40MS`, `DELAY_5MS`, `DELAY_100US` o `DELAY_2MS` según el estado) antes de que `en_cnt` cuente hasta `EN_HIGH_T` (1250 ciclos × 20 ns = 25 µs) y se genere el pulso en `E` que la LCD usa para capturar el dato.

### 3.2 Transmisión de datos (estáticos y dinámicos)

* ![Simulación Escritura](ruta_a_tu_imagen_sim_data.png)
* **Análisis:** al entrar en los estados de escritura de caracteres, `RS` cambia a `1`. En la fase dinámica se verifica que `a_dec_ascii`/`a_uni_ascii` (y su equivalente para el canal B) contengan el valor decimal de `entrada_a`/`entrada_b` correctamente codificado en ASCII (sumando `0x30`), y que la etiqueta `a_r0..a_r3` cambie entre `BAJO`, `MEDI` y `ALTO` según el valor de la entrada en el instante de la captura.
* **Periodo de refresco:** sumando los `~32` estados de la rama de escritura (estados `8` a `39`) con `DELAY_2MS` cada uno, el ciclo completo de refresco dura aproximadamente `64 ms`. Esto explica por qué, aunque la FSM nunca se detiene, el cambio de los switches se ve reflejado en pantalla casi de inmediato para un observador humano.

> **Nota:** reemplaza las rutas de imagen anteriores por tus capturas reales de ModelSim (formas de onda de `clk`, `rs`, `en`, `dat` y `state`).

---

---

## 4. Implementación

### 4.1 Configuración Física y Asignación de Pines
La implementación se realizó sobre la tarjeta **Altera Cyclone IV**. Se conectaron las 8 líneas de datos (`D0`–`D7`) además de `RS`, `RW` y `E`, ya que, como se mostró en la sección 1, el `Function Set 0x38` configura el controlador HD44780 en **interfaz de 8 bits**. La pantalla se conectó respetando la orientación del pin 1 del *header* de la PCB, y la asignación de pines en el *Pin Planner* de Quartus Prime se realizó según la serigrafía de la tarjeta.

Para garantizar el correcto funcionamiento del bit de datos conectado al **pin 101**, se modificó su comportamiento predeterminado en Quartus:
1. `Assignments` → `Device` → `Device and Pin Options`.
2. Categoría: `Dual-Purpose Pins`.
3. Modificación del pin `nCEO` a **"Use as regular I/O"**.

### 4.2 Evidencia del Funcionamiento en Hardware
A continuación se muestran los resultados finales en la tarjeta de desarrollo:

#### Parte 1: Texto Estático
 
![Resultado Parte 1](Imagenes/5enlab.jpeg)
*Descripción:* visualización exitosa del texto fijo `"5 en este"` (fila 1) y `"laboratorio"` (fila 2), generado por el módulo `LCD`.


#### Parte 2: Texto Dinámico con Entradas de 8 bits

Las imágenes están ordenadas del estado `0` al `15` (valor mostrado en ambos canales) y muestran capturas tomadas durante la implementación en la FPGA, generadas por el módulo `lcd_parte2`. En cada una se observa el valor decimal junto a su etiqueta de clasificación (`BAJO`/`MEDI`/`ALTO`).

|  |  |  |  |
|---|---|---|---|
| ![Estado 0](Imagenes/tabla%20evidencias/0.jpg)<br>**Estado 0** | ![Estado 1](Imagenes/tabla%20evidencias/1.jpg)<br>**Estado 1** | ![Estado 2](Imagenes/tabla%20evidencias/2.jpg)<br>**Estado 2** | ![Estado 3](Imagenes/tabla%20evidencias/3.jpg)<br>**Estado 3** |
| ![Estado 4](Imagenes/tabla%20evidencias/4.jpg)<br>**Estado 4** | ![Estado 5](Imagenes/tabla%20evidencias/5.jpg)<br>**Estado 5** | ![Estado 6](Imagenes/tabla%20evidencias/6.jpg)<br>**Estado 6** | ![Estado 7](Imagenes/tabla%20evidencias/7.jpg)<br>**Estado 7** |
| ![Estado 8](Imagenes/tabla%20evidencias/8.jpg)<br>**Estado 8** | ![Estado 9](Imagenes/tabla%20evidencias/9.jpg)<br>**Estado 9** | ![Estado 10](Imagenes/tabla%20evidencias/10.jpg)<br>**Estado 10** | ![Estado 11](Imagenes/tabla%20evidencias/11.jpg)<br>**Estado 11** |
| ![Estado 12](Imagenes/tabla%20evidencias/12.jpg)<br>**Estado 12** | ![Estado 13](Imagenes/tabla%20evidencias/13.jpeg)<br>**Estado 13** | ![Estado 14](Imagenes/tabla%20evidencias/14.jpeg)<br>**Estado 14** | ![Estado 15](Imagenes/tabla%20evidencias/15.jpg)<br>**Estado 15** |


Se verifica que para los 16 valores posibles de cada entrada (0–15) la etiqueta de clasificación corresponde a lo definido en la lógica combinacional de la sección 1: estados 0–4 muestran `BAJO`, estados 5–10 muestran `MEDI` y estados 11–15 muestran `ALTO`.

---

## 5. Conclusiones

* La separación entre lógica combinacional (conversión BIN→ASCII y clasificación de rango) y lógica secuencial (FSM de control) facilitó la depuración: los cambios en el formato del mensaje no requirieron tocar la temporización, y viceversa.
* El mecanismo de `busy`/`delay_cnt`/`wait_time` permitió generalizar la espera entre comandos sin necesidad de estados separados para cada tiempo distinto del datasheet (40 ms, 5 ms, 100 µs, 2 ms), reduciendo la cantidad de código repetido.
* Confirmar la interfaz real (8 bits, según el comando `0x38`) frente a lo asumido inicialmente (4 bits) fue clave: una FSM de inicialización incorrecta para el modo de la LCD habría impedido cualquier comunicación válida con el controlador HD44780.
* El diseño de refresco continuo en la fase dinámica (sin un estado de "espera de cambio") simplifica el control a costa de un pequeño retardo de actualización (~64 ms por ciclo completo), que en la práctica es imperceptible para un usuario.
* La implementación en hardware sobre los 16 valores posibles (0–15) para ambos canales confirmó que la conversión a ASCII y la clasificación por rango funcionan de forma consistente con lo simulado.

---

## 6. Referencias

* Hitachi. *HD44780U (LCD-II) Dot Matrix Liquid Crystal Display Controller/Driver* — datasheet del controlador utilizado por la pantalla LCD 16x2.
* Intel/Altera. *Cyclone IV Device Handbook* — documentación de la FPGA utilizada para la implementación.
* Intel. *Quartus Prime Pin Planner User Guide* — referencia para la asignación de pines y configuración de pines de propósito dual.
* IEEE Std 1364. *IEEE Standard for Verilog Hardware Description Language*.
