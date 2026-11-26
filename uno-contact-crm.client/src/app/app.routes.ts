import { Routes } from '@angular/router';
import { cambioContrasenaGuard, perfilGuard, requiereCambioGuard, sesionGuard } from './core/sesion/perfil.guard';
import { Acceso } from './features/acceso/acceso';
import { AccesoDenegado } from './features/acceso-denegado/acceso-denegado';
import { Inicio } from './features/inicio/inicio';
import { Herramienta } from './features/herramienta/herramienta';
import { Shell } from './layout/shell';
import { EnConstruccion } from './shared/en-construccion/en-construccion';

/** Perfiles con acceso a Gestión y Herramientas (FRM_GESTION_CARTERA). */
const gestion = ['Asesor', 'Supervisor', 'Administrador'] as const;

export const routes: Routes = [
  { path: 'acceso', component: Acceso, title: 'Iniciar sesión · UNO Contact CRM' },
  {
    path: 'cambiar-contrasena',
    canActivate: [requiereCambioGuard],
    loadComponent: () =>
      import('./features/cambiar-contrasena/cambiar-contrasena').then((m) => m.CambiarContrasena),
    title: 'Cambiar contraseña · UNO Contact CRM',
  },
  {
    path: '',
    component: Shell,
    canActivate: [sesionGuard, cambioContrasenaGuard],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'inicio' },
      { path: 'inicio', component: Inicio, title: 'Inicio · UNO Contact CRM' },

      // --- Menú Gestión (4 submenús del legacy) ---
      {
        path: 'asesor',
        canMatch: [perfilGuard(...gestion)],
        loadComponent: () =>
          import('./features/gestion/gestion').then((m) => m.Gestion),
        title: 'Nueva Gestion · UNO Contact CRM',
      },
      {
        path: 'gestion/bloquear',
        canMatch: [perfilGuard(...gestion)],
        component: Herramienta,
        data: { modo: 'bloquear' },
        title: 'Bloquear · UNO Contact CRM',
      },
      {
        path: 'gestion/cancelar',
        canMatch: [perfilGuard(...gestion)],
        component: Herramienta,
        data: { modo: 'cancelar' },
        title: 'Cancelar · UNO Contact CRM',
      },
      {
        path: 'gestion/agendar-llamada',
        canMatch: [perfilGuard(...gestion)],
        component: Herramienta,
        data: { modo: 'agendar-llamada' },
        title: 'Agendar Llamada · UNO Contact CRM',
      },

      // --- Menú Herramientas (7 submenús del legacy) ---
      {
        path: 'herramientas/buscar',
        canMatch: [perfilGuard(...gestion)],
        component: Herramienta,
        data: { modo: 'buscar' },
        title: 'Buscar · UNO Contact CRM',
      },
      {
        path: 'herramientas/notas',
        canMatch: [perfilGuard(...gestion)],
        component: Herramienta,
        data: { modo: 'notas' },
        title: 'Notas · UNO Contact CRM',
      },
      {
        path: 'herramientas/bloc-notas',
        canMatch: [perfilGuard(...gestion)],
        component: Herramienta,
        data: { modo: 'bloc-notas' },
        title: 'Bloc de Notas · UNO Contact CRM',
      },
      {
        path: 'herramientas/calculadora',
        canMatch: [perfilGuard(...gestion)],
        component: Herramienta,
        data: { modo: 'calculadora' },
        title: 'Calculadora · UNO Contact CRM',
      },
      {
        path: 'herramientas/actualiza-informacion',
        canMatch: [perfilGuard(...gestion)],
        component: Herramienta,
        data: { modo: 'actualiza-informacion' },
        title: 'Actualiza Información · UNO Contact CRM',
      },
      {
        path: 'herramientas/expedientes',
        canMatch: [perfilGuard(...gestion)],
        component: Herramienta,
        data: { modo: 'expedientes' },
        title: 'Expedientes · UNO Contact CRM',
      },
      {
        path: 'herramientas/softphone',
        canMatch: [perfilGuard(...gestion)],
        component: Herramienta,
        data: { modo: 'softphone' },
        title: 'Softphone · UNO Contact CRM',
      },

      {
        path: 'supervision',
        canMatch: [perfilGuard('Supervisor')],
        component: EnConstruccion,
        data: { titulo: 'Supervisión' },
        title: 'Supervisión · UNO Contact CRM',
      },

      // --- Área de Administración ---
      {
        path: 'administracion',
        pathMatch: 'full',
        redirectTo: 'administracion/empleados',
      },
      {
        path: 'administracion/empleados',
        canMatch: [perfilGuard('Administrador')],
        loadComponent: () =>
          import('./features/empleados/empleados').then((m) => m.Empleados),
        title: 'Consulta de empleados · UNO Contact CRM',
      },
      {
        path: 'administracion/alta-empleados',
        canMatch: [perfilGuard('Administrador')],
        loadComponent: () =>
          import('./features/alta-empleados/alta-empleados').then((m) => m.AltaEmpleados),
        title: 'Alta de empleados · UNO Contact CRM',
      },
      {
        path: 'administracion/asignar-personal',
        canMatch: [perfilGuard('Administrador')],
        loadComponent: () =>
          import('./features/asignar-personal/asignar-personal').then((m) => m.AsignarPersonal),
        title: 'Asignar personal · UNO Contact CRM',
      },
      {
        path: 'administracion/cambiar-cartera',
        canMatch: [perfilGuard('Administrador')],
        loadComponent: () =>
          import('./features/cambiar-cartera/cambiar-cartera').then((m) => m.CambiarCartera),
        title: 'Cambia cartera · UNO Contact CRM',
      },
      {
        path: 'administracion/carga-asignaciones',
        canMatch: [perfilGuard('Administrador')],
        loadComponent: () =>
          import('./features/carga-asignaciones/carga-asignaciones').then((m) => m.CargaAsignaciones),
        title: 'Carga de asignaciones · UNO Contact CRM',
      },
      {
        path: 'administracion/usuarios',
        canMatch: [perfilGuard('Administrador')],
        loadComponent: () =>
          import('./features/usuarios/usuarios').then((m) => m.Usuarios),
        title: 'Usuarios · UNO Contact CRM',
      },
      { path: 'acceso-denegado', component: AccesoDenegado, title: 'Acceso denegado · UNO Contact CRM' },
    ],
  },
  { path: '**', redirectTo: '' },
];
