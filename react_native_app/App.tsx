// Version: 2026-02-15
/**
 * Main App Entry Point
 * Basic navigation setup
 */

import React, { useEffect, useState } from 'react';
import { StyleSheet, Text, View, ActivityIndicator } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { initDatabase } from './src/services/database';

const Tab = createBottomTabNavigator();

// Placeholder screens
const HomeScreen = () => (
  <View style={styles.screen}>
    <Text style={styles.title}>伝票履歴</Text>
    <Text style={styles.subtitle}>販売アシスト1号 v2.0.0</Text>
    <Text style={styles.info}>React Native (Expo) 版</Text>
  </View>
);

const CreateScreen = () => (
  <View style={styles.screen}>
    <Text style={styles.title}>新規作成</Text>
    <Text style={styles.subtitle}>Coming Soon...</Text>
  </View>
);

const SettingsScreen = () => (
  <View style={styles.screen}>
    <Text style={styles.title}>設定・マスター管理</Text>
    <Text style={styles.subtitle}>Coming Soon...</Text>
  </View>
);

export default function App() {
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    const initialize = async () => {
      try {
        await initDatabase();
        console.log('Database initialized successfully');
      } catch (error) {
        console.error('Failed to initialize database:', error);
      } finally {
        setIsReady(true);
      }
    };

    initialize();
  }, []);

  if (!isReady) {
    return (
      <View style={styles.loading}>
        <ActivityIndicator size="large" color="#607D8B" />
        <Text style={styles.loadingText}>データベース初期化中...</Text>
      </View>
    );
  }

  return (
    <NavigationContainer>
      <Tab.Navigator
        screenOptions={{
          tabBarActiveTintColor: '#607D8B',
          tabBarInactiveTintColor: '#999',
          headerStyle: {
            backgroundColor: '#607D8B',
          },
          headerTintColor: '#fff',
        }}
      >
        <Tab.Screen
          name="Home"
          component={HomeScreen}
          options={{ title: '履歴' }}
        />
        <Tab.Screen
          name="Create"
          component={CreateScreen}
          options={{ title: '新規作成' }}
        />
        <Tab.Screen
          name="Settings"
          component={SettingsScreen}
          options={{ title: '設定' }}
        />
      </Tab.Navigator>
      <StatusBar style="auto" />
    </NavigationContainer>
  );
}

const styles = StyleSheet.create({
  loading: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#666',
  },
  screen: {
    flex: 1,
    backgroundColor: '#f5f5f5',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 8,
    color: '#333',
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    marginBottom: 4,
  },
  info: {
    fontSize: 14,
    color: '#999',
  },
});
