import { Routes } from '@angular/router';
import { cambioContrasenaGuard, permisoGuard, requiereCambioGuard, sesionGuard } from './core/sesion/perfil.guard';
import { Acceso } from './features/acceso/acceso';
import { AccesoDenegado } from './features/acceso-denegado/acceso-denegado';
import { Inicio } from './features/inicio/inicio';
import { Herramienta } from './features/herramienta/herramienta';
import { Shell } from './layout/shell';

export const routes: Routes = [
  { path: 'acceso', component: Acceso, title: 'Iniciar sesión · UNO Contact' },
  {
    path: 'cambiar-contrasena',
    canActivate: [requiereCambioGuard],
    loadComponent: () =>
      import('./features/cambiar-contrasena/cambiar-contrasena').then((m) => m.CambiarContrasena),
    title: 'Cambiar contraseña · UNO Contact',
  },
  {
    path: '',
    component: Shell,
    canActivate: [sesionGuard, cambioContrasenaGuard],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'inicio' },
      { path: 'inicio', component: Inicio, title: 'Inicio · UNO Contact' },

      // --- Menú Gestión (4 submenús del legacy) ---
      {
        path: 'asesor',
        canMatch: [permisoGuard('gestion-nueva')],
        loadComponent: () =>
          import('./features/gestion/gestion').then((m) => m.Gestion),
        title: 'Nueva Gestion · UNO Contact',
      },
      {
        path: 'gestion/bloquear',
        canMatch: [permisoGuard('gestion-bloquear')],
        component: Herramienta,
        data: { modo: 'bloquear' },
        title: 'Bloquear · UNO Contact',
      },
      {
        path: 'gestion/cancelar',
        canMatch: [permisoGuard('gestion-cancelar')],
        component: Herramienta,
        data: { modo: 'cancelar' },
        title: 'Cancelar · UNO Contact',
      },
      {
        path: 'gestion/agendar-llamada',
        canMatch: [permisoGuard('gestion-agendar')],
        component: Herramienta,
        data: { modo: 'agendar-llamada' },
        title: 'Agendar Llamada · UNO Contact',
      },

      // --- Menú Herramientas (7 submenús del legacy) ---
      {
        path: 'herramientas/buscar',
        canMatch: [permisoGuard('herramientas-buscar')],
        component: Herramienta,
        data: { modo: 'buscar' },
        title: 'Buscar · UNO Contact',
      },
      {
        path: 'herramientas/notas',
        canMatch: [permisoGuard('herramientas-notas')],
        component: Herramienta,
        data: { modo: 'notas' },
        title: 'Notas · UNO Contact',
      },
      {
        path: 'herramientas/bloc-notas',
        canMatch: [permisoGuard('herramientas-bloc')],
        component: Herramienta,
        data: { modo: 'bloc-notas' },
        title: 'Bloc de Notas · UNO Contact',
      },
      {
        path: 'herramientas/calculadora',
        canMatch: [permisoGuard('herramientas-calculadora')],
        component: Herramienta,
        data: { modo: 'calculadora' },
        title: 'Calculadora · UNO Contact',
      },
      {
        path: 'herramientas/actualiza-informacion',
        canMatch: [permisoGuard('herramientas-actualiza')],
        component: Herramienta,
        data: { modo: 'actualiza-informacion' },
        title: 'Actualiza Información · UNO Contact',
      },
      {
        path: 'herramientas/expedientes',
        canMatch: [permisoGuard('herramientas-expedientes')],
        component: Herramienta,
        data: { modo: 'expedientes' },
        title: 'Expedientes · UNO Contact',
      },
      {
        path: 'herramientas/softphone',
        canMatch: [permisoGuard('herramientas-softphone')],
        component: Herramienta,
        data: { modo: 'softphone' },
        title: 'Softphone · UNO Contact',
      },

      // --- Área de Administración ---
      {
        path: 'administracion',
        pathMatch: 'full',
        redirectTo: 'administracion/empleados',
      },
      {
        path: 'administracion/empleados',
        canMatch: [permisoGuard('empleados')],
        loadComponent: () =>
          import('./features/empleados/empleados').then((m) => m.Empleados),
        title: 'Consulta de empleados · UNO Contact',
      },
      {
        path: 'administracion/alta-empleados',
        canMatch: [permisoGuard('alta-empleados')],
        loadComponent: () =>
          import('./features/alta-empleados/alta-empleados').then((m) => m.AltaEmpleados),
        title: 'Alta de empleados · UNO Contact',
      },
      {
        path: 'administracion/asignar-personal',
        canMatch: [permisoGuard('asignar-personal')],
        loadComponent: () =>
          import('./features/asignar-personal/asignar-personal').then((m) => m.AsignarPersonal),
        title: 'Asignar personal · UNO Contact',
      },
      {
        path: 'administracion/cambiar-cartera',
        canMatch: [permisoGuard('cambiar-cartera')],
        loadComponent: () =>
          import('./features/cambiar-cartera/cambiar-cartera').then((m) => m.CambiarCartera),
        title: 'Cambia cartera · UNO Contact',
      },
      {
        path: 'administracion/carga-asignaciones',
        canMatch: [permisoGuard('carga-asignaciones')],
        loadComponent: () =>
          import('./features/carga-asignaciones/carga-asignaciones').then((m) => m.CargaAsignaciones),
        title: 'Carga de asignaciones · UNO Contact',
      },
      {
        path: 'administracion/usuarios',
        canMatch: [permisoGuard('usuarios')],
        loadComponent: () =>
          import('./features/usuarios/usuarios').then((m) => m.Usuarios),
        title: 'Usuarios · UNO Contact',
      },
      {
        path: 'administracion/bajas',
        canMatch: [permisoGuard('bajas')],
        loadComponent: () =>
          import('./features/bajas/bajas').then((m) => m.Bajas),
        title: 'Bajas de personal · UNO Contact',
      },
      { path: 'acceso-denegado', component: AccesoDenegado, title: 'Acceso denegado · UNO Contact' },
    ],
  },
  { path: '**', redirectTo: '' },
];
