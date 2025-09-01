import React, { useState, useEffect } from 'react';
import {
  View,
  ScrollView,
  StyleSheet,
  Alert,
  RefreshControl,
  Dimensions
} from 'react-native';
import {
  Card,
  Title,
  Paragraph,
  Button,
  TextInput,
  Chip,
  FAB,
  Portal,
  Modal,
  List,
  Divider,
  Surface,
  useTheme,
  ActivityIndicator,
  Banner
} from 'react-native-paper';
import QRCode from 'react-native-qrcode-svg';
import * as Location from 'expo-location';
import { BarCodeScanner } from 'expo-barcode-scanner';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useForm, Controller } from 'react-hook-form';
import { format } from 'date-fns';
import { useAuthStore } from '../stores/authStore';
import { walletService } from '../services/walletService';
import { offlineService } from '../services/offlineService';

const { width } = Dimensions.get('window');

interface Transaction {
  id: string;
  transactionId: string;
  amount: number;
  type: 'CREDIT' | 'DEBIT' | 'REFUND';
  description: string;
  createdAt: string;
  store?: {
    name: string;
    code: string;
  };
}

const DigitalWalletScreen: React.FC = () => {
  const theme = useTheme();
  const queryClient = useQueryClient();
  const { user } = useAuthStore();
  const [scannerVisible, setScannerVisible] = useState(false);
  const [transactionModalVisible, setTransactionModalVisible] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [location, setLocation] = useState<Location.LocationObject | null>(null);
  const [hasLocationPermission, setHasLocationPermission] = useState(false);
  const [hasCameraPermission, setHasCameraPermission] = useState(false);
  const [offlineMode, setOfflineMode] = useState(false);

  const { control, handleSubmit, reset, formState: { errors } } = useForm({
    defaultValues: {
      amount: '',
      description: '',
      pin: ''
    }
  });

  // Fetch wallet data
  const { data: wallet, isLoading: walletLoading } = useQuery({
    queryKey: ['wallet', user?.id],
    queryFn: () => walletService.getWallet(user?.id!),
    enabled: !!user?.id,
    staleTime: 30000
  });

  // Fetch transaction history
  const { data: transactions, isLoading: transactionsLoading } = useQuery({
    queryKey: ['transactions', wallet?.id],
    queryFn: () => walletService.getTransactions(wallet?.id!),
    enabled: !!wallet?.id
  });

  // Transaction mutation
  const transactionMutation = useMutation({
    mutationFn: (data: any) => {
      if (offlineMode) {
        return offlineService.saveTransaction(data);
      }
      return walletService.createTransaction(data);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['wallet'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      setTransactionModalVisible(false);
      reset();
      Alert.alert('Success', 'Transaction completed successfully');
    },
    onError: (error: any) => {
      Alert.alert('Error', error.message || 'Transaction failed');
    }
  });

  // Request permissions
  useEffect(() => {
    (async () => {
      // Location permission
      const { status: locationStatus } = await Location.requestForegroundPermissionsAsync();
      setHasLocationPermission(locationStatus === 'granted');

      // Camera permission
      const { status: cameraStatus } = await BarCodeScanner.requestPermissionsAsync();
      setHasCameraPermission(cameraStatus === 'granted');

      // Get current location
      if (locationStatus === 'granted') {
        const currentLocation = await Location.getCurrentPositionAsync({});
        setLocation(currentLocation);
      }
    })();
  }, []);

  // Check network status
  useEffect(() => {
    const checkNetwork = async () => {
      const isConnected = await offlineService.isConnected();
      setOfflineMode(!isConnected);
    };

    checkNetwork();
    const interval = setInterval(checkNetwork, 5000);
    return () => clearInterval(interval);
  }, []);

  // Sync offline transactions
  useEffect(() => {
    if (!offlineMode && wallet?.id) {
      offlineService.syncTransactions(wallet.id);
    }
  }, [offlineMode, wallet?.id]);

  const onRefresh = async () => {
    setRefreshing(true);
    await queryClient.invalidateQueries({ queryKey: ['wallet'] });
    await queryClient.invalidateQueries({ queryKey: ['transactions'] });
    setRefreshing(false);
  };

  const handleBarCodeScanned = ({ type, data }: { type: string; data: string }) => {
    setScannerVisible(false);
    try {
      const scannedData = JSON.parse(data);
      if (scannedData.type === 'MERCHANT_QR') {
        // Handle merchant QR code
        Alert.alert('Merchant Scanned', `Store: ${scannedData.storeName}`);
      }
    } catch (error) {
      Alert.alert('Invalid QR Code', 'Please scan a valid merchant QR code');
    }
  };

  const onSubmitTransaction = async (data: any) => {
    if (!location && hasLocationPermission) {
      const currentLocation = await Location.getCurrentPositionAsync({});
      setLocation(currentLocation);
    }

    const transactionData = {
      walletId: wallet?.id,
      amount: parseFloat(data.amount),
      type: 'DEBIT',
      description: data.description,
      pin: data.pin,
      location: location ? {
        latitude: location.coords.latitude,
        longitude: location.coords.longitude
      } : undefined
    };

    transactionMutation.mutate(transactionData);
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(amount);
  };

  if (walletLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={theme.colors.primary} />
      </View>
    );
  }

  if (!wallet) {
    return (
      <View style={styles.container}>
        <Card style={styles.errorCard}>
          <Card.Content>
            <Title>No Wallet Found</Title>
            <Paragraph>Please contact your administrator to set up a digital wallet.</Paragraph>
          </Card.Content>
        </Card>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ScrollView
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
      >
        {offlineMode && (
          <Banner
            visible={true}
            icon="wifi-off"
            actions={[]}
          >
            Offline Mode - Transactions will sync when connected
          </Banner>
        )}

        {/* Wallet Card */}
        <Card style={styles.walletCard}>
          <Card.Content>
            <View style={styles.walletHeader}>
              <View>
                <Title style={styles.walletNumber}>{wallet.walletNumber}</Title>
                <Paragraph>Digital Wallet</Paragraph>
              </View>
              <Chip
                mode="flat"
                style={[
                  styles.statusChip,
                  { backgroundColor: wallet.status === 'ACTIVE' ? theme.colors.primary : theme.colors.error }
                ]}
                textStyle={{ color: 'white' }}
              >
                {wallet.status}
              </Chip>
            </View>

            <Divider style={styles.divider} />

            <View style={styles.balanceContainer}>
              <Paragraph>Available Balance</Paragraph>
              <Title style={styles.balance}>{formatCurrency(wallet.balance)}</Title>
              <Paragraph style={styles.creditLimit}>
                Credit Limit: {formatCurrency(wallet.creditLimit)}
              </Paragraph>
            </View>

            <View style={styles.qrContainer}>
              <QRCode
                value={wallet.qrCode}
                size={width * 0.5}
                backgroundColor="white"
                color={theme.colors.primary}
              />
            </View>

            <View style={styles.statsContainer}>
              <View style={styles.stat}>
                <Paragraph>Spent</Paragraph>
                <Title>{formatCurrency(wallet.spentAmount)}</Title>
              </View>
              <View style={styles.stat}>
                <Paragraph>Utilization</Paragraph>
                <Title>{Math.round((wallet.spentAmount / wallet.creditLimit) * 100)}%</Title>
              </View>
            </View>
          </Card.Content>
        </Card>

        {/* Recent Transactions */}
        <Card style={styles.transactionsCard}>
          <Card.Title title="Recent Transactions" />
          <Card.Content>
            {transactionsLoading ? (
              <ActivityIndicator />
            ) : transactions && transactions.length > 0 ? (
              <List.Section>
                {transactions.slice(0, 5).map((transaction: Transaction) => (
                  <React.Fragment key={transaction.id}>
                    <List.Item
                      title={transaction.description}
                      description={`${transaction.store?.name || 'N/A'} • ${format(new Date(transaction.createdAt), 'MMM dd, yyyy')}`}
                      left={() => (
                        <List.Icon
                          icon={transaction.type === 'DEBIT' ? 'arrow-up' : 'arrow-down'}
                          color={transaction.type === 'DEBIT' ? theme.colors.error : theme.colors.primary}
                        />
                      )}
                      right={() => (
                        <Title
                          style={{
                            color: transaction.type === 'DEBIT' ? theme.colors.error : theme.colors.primary
                          }}
                        >
                          {transaction.type === 'DEBIT' ? '-' : '+'}{formatCurrency(transaction.amount)}
                        </Title>
                      )}
                    />
                    <Divider />
                  </React.Fragment>
                ))}
              </List.Section>
            ) : (
              <Paragraph>No transactions yet</Paragraph>
            )}
          </Card.Content>
          {transactions && transactions.length > 5 && (
            <Card.Actions>
              <Button onPress={() => {}}>View All</Button>
            </Card.Actions>
          )}
        </Card>
      </ScrollView>

      {/* FAB for new transaction */}
      <FAB
        style={styles.fab}
        icon="plus"
        onPress={() => setTransactionModalVisible(true)}
        label="New Transaction"
      />

      {/* Transaction Modal */}
      <Portal>
        <Modal
          visible={transactionModalVisible}
          onDismiss={() => setTransactionModalVisible(false)}
          contentContainerStyle={styles.modal}
        >
          <Title style={styles.modalTitle}>New Transaction</Title>
          
          <Controller
            control={control}
            name="amount"
            rules={{
              required: 'Amount is required',
              pattern: {
                value: /^\d+(\.\d{1,2})?$/,
                message: 'Invalid amount format'
              }
            }}
            render={({ field: { onChange, onBlur, value } }) => (
              <TextInput
                label="Amount"
                value={value}
                onChangeText={onChange}
                onBlur={onBlur}
                keyboardType="decimal-pad"
                mode="outlined"
                error={!!errors.amount}
                style={styles.input}
                left={<TextInput.Affix text="$" />}
              />
            )}
          />
          {errors.amount && (
            <Paragraph style={styles.error}>{errors.amount.message}</Paragraph>
          )}

          <Controller
            control={control}
            name="description"
            rules={{ required: 'Description is required' }}
            render={({ field: { onChange, onBlur, value } }) => (
              <TextInput
                label="Description"
                value={value}
                onChangeText={onChange}
                onBlur={onBlur}
                mode="outlined"
                multiline
                numberOfLines={3}
                error={!!errors.description}
                style={styles.input}
              />
            )}
          />
          {errors.description && (
            <Paragraph style={styles.error}>{errors.description.message}</Paragraph>
          )}

          <Controller
            control={control}
            name="pin"
            rules={{
              required: 'PIN is required',
              minLength: {
                value: 4,
                message: 'PIN must be 4 digits'
              }
            }}
            render={({ field: { onChange, onBlur, value } }) => (
              <TextInput
                label="PIN"
                value={value}
                onChangeText={onChange}
                onBlur={onBlur}
                keyboardType="numeric"
                secureTextEntry
                mode="outlined"
                maxLength={4}
                error={!!errors.pin}
                style={styles.input}
              />
            )}
          />
          {errors.pin && (
            <Paragraph style={styles.error}>{errors.pin.message}</Paragraph>
          )}

          <View style={styles.modalActions}>
            <Button
              mode="outlined"
              onPress={() => {
                setTransactionModalVisible(false);
                reset();
              }}
              style={styles.modalButton}
            >
              Cancel
            </Button>
            <Button
              mode="contained"
              onPress={handleSubmit(onSubmitTransaction)}
              loading={transactionMutation.isPending}
              style={styles.modalButton}
            >
              Submit
            </Button>
          </View>
        </Modal>
      </Portal>

      {/* QR Scanner Modal */}
      <Portal>
        <Modal
          visible={scannerVisible}
          onDismiss={() => setScannerVisible(false)}
          contentContainerStyle={styles.scannerModal}
        >
          {hasCameraPermission ? (
            <BarCodeScanner
              onBarCodeScanned={handleBarCodeScanned}
              style={StyleSheet.absoluteFillObject}
            />
          ) : (
            <View style={styles.permissionContainer}>
              <Paragraph>Camera permission is required to scan QR codes</Paragraph>
            </View>
          )}
          <Button
            mode="contained"
            onPress={() => setScannerVisible(false)}
            style={styles.scannerClose}
          >
            Close
          </Button>
        </Modal>
      </Portal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5'
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center'
  },
  errorCard: {
    margin: 16
  },
  walletCard: {
    margin: 16,
    elevation: 4
  },
  walletHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center'
  },
  walletNumber: {
    fontSize: 20,
    fontWeight: 'bold'
  },
  statusChip: {
    height: 28
  },
  divider: {
    marginVertical: 16
  },
  balanceContainer: {
    alignItems: 'center',
    marginBottom: 16
  },
  balance: {
    fontSize: 36,
    fontWeight: 'bold',
    marginVertical: 8
  },
  creditLimit: {
    color: '#666'
  },
  qrContainer: {
    alignItems: 'center',
    marginVertical: 16
  },
  statsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginTop: 16
  },
  stat: {
    alignItems: 'center'
  },
  transactionsCard: {
    margin: 16,
    marginTop: 0,
    elevation: 4
  },
  fab: {
    position: 'absolute',
    margin: 16,
    right: 0,
    bottom: 0
  },
  modal: {
    backgroundColor: 'white',
    padding: 20,
    margin: 20,
    borderRadius: 8
  },
  modalTitle: {
    marginBottom: 16,
    textAlign: 'center'
  },
  input: {
    marginBottom: 8
  },
  error: {
    color: 'red',
    fontSize: 12,
    marginBottom: 8
  },
  modalActions: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 16
  },
  modalButton: {
    flex: 0.48
  },
  scannerModal: {
    flex: 1,
    backgroundColor: 'black'
  },
  scannerClose: {
    position: 'absolute',
    bottom: 50,
    alignSelf: 'center'
  },
  permissionContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20
  }
});

export default DigitalWalletScreen;