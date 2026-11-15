import React from 'react';
import { createRoot } from 'react-dom/client';

import './styles/tokens.css';
import './styles/app.css';
import './styles/home.css';
import './styles/pages.css';
import './styles/px-cal.css';
import './styles/px-mine.css';
import './styles/px-settings.css';
import './styles/px-grade.css';
import './styles/px-login.css';
import './styles/px-appearance.css';
import './styles/px-widget.css';
import './styles/px-courselist.css';
import './styles/avatar-crop.css';

import { SplashScreen } from '@capacitor/splash-screen';

import { AppProvider } from './core/appState';
import App from './App';

const el = document.getElementById('root');
if (!el) throw new Error('#root 不存在');

createRoot(el).render(
  <React.StrictMode>
    <AppProvider>
      <App />
    </AppProvider>
  </React.StrictMode>
);
