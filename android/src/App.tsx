import { checkAppUpdate } from './core/appUpdate';
import { useEffect } from 'react';
import { App as CapApp } from '@capacitor/app';

import { back, useRoute } from './core/router';
import { ToastHost } from './ui/toast';
import BottomTabs from './components/BottomTabs';

import AboutPage from './pages/AboutPage';
import AcademicCalendar from './pages/AcademicCalendar';
import AccountPage from './pages/AccountPage';
import AddCoursePage from './pages/AddCoursePage';
import AppearancePage from './pages/AppearancePage';
import CourseListPage from './pages/CourseListPage';
import ExamPage from './pages/ExamPage';
import ExamWebPage from './pages/ExamWebPage';
import FaqPage from './pages/FaqPage';
import FeedbackPage from './pages/FeedbackPage';
import GradePage from './pages/GradePage';
import HomePage from './pages/HomePage';
import LoginPage from './pages/LoginPage';
import MorePage from './pages/MorePage';
import PeriodSettings from './pages/PeriodSettings';
import PersonalInfoPage from './pages/PersonalInfoPage';
import PrivacyDocPage from './pages/PrivacyDocPage';
import ProfilePage from './pages/ProfilePage';
import RemindPage from './pages/RemindPage';
import TermPage from './pages/TermPage';
import TimetableSettings from './pages/TimetableSettings';
import WidgetGuide from './pages/WidgetGuide';

const PAGES: Record<string, () => JSX.Element> = {
  '/home': HomePage,
  '/login': LoginPage,
  '/periods': PeriodSettings,
  '/courses': CourseListPage,
  '/timetable-settings': TimetableSettings,
  '/account': AccountPage,
  '/about': AboutPage,
  '/term': TermPage,
  '/appearance': AppearancePage,
  '/remind': RemindPage,
  '/widget': WidgetGuide,
  '/calendar': AcademicCalendar,
  '/grades': GradePage,
  '/exam': ExamPage,
  '/exam-web': ExamWebPage,
  '/profile': ProfilePage,
  '/personal': PersonalInfoPage,
  '/feedback': FeedbackPage,
  '/add-course': AddCoursePage,
  '/faq': FaqPage,
  '/more': MorePage
};

/** 前缀型路由：/privacy/collect 这类带参数的分派到这里 */
const PREFIX: [string, () => JSX.Element][] = [['/privacy/', PrivacyDocPage]];

export default function App() {
  useEffect(() => { void checkAppUpdate(true); }, []);
  const { path } = useRoute();
  const exact = PAGES[path];
  const Prefixed = !exact ? PREFIX.find(([p]) => path.startsWith(p))?.[1] : undefined;
  const Page = exact ?? Prefixed;
  const tabIndex = ['/calendar', '/home', '/grades', '/profile'].indexOf(path);

  // Android 物理返回键：有上一页就回上一页，已经在首页就交回系统（退出 App）
  useEffect(() => {
    const pending = CapApp.addListener('backButton', () => {
      const here = window.location.hash.replace(/^#/, '') || '/home';
      if (here === '/home' || here === '') {
        CapApp.exitApp();
        return;
      }
      back();
    });
    return () => {
      void pending.then((h) => h.remove());
    };
  }, []);

  return (
    <div className="app-root">
      <div className="route-view" key={path}>
        {Page ? <Page /> : <HomePage />}
      </div>
      {tabIndex >= 0 && <BottomTabs current={tabIndex} />}
      <ToastHost />
    </div>
  );
}
