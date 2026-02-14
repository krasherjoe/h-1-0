// Version: 2026-02-15
/**
 * Document Type Selection Component
 * Migrated from Flutter _buildDocumentTypeSection()
 */

import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Picker } from '@react-native-picker/picker';
import { DocumentType, getDocumentTypeName } from '../../models';

interface DocumentTypeSectionProps {
    value: DocumentType;
    onChange: (type: DocumentType) => void;
}

export const DocumentTypeSection: React.FC<DocumentTypeSectionProps> = ({
    value,
    onChange,
}) => {
    const documentTypes: DocumentType[] = [
        'invoice',
        'quotation',
        'delivery',
        'receipt',
        'statement',
    ];

    return (
        <View style={styles.container}>
            <Text style={styles.label}>伝票種別</Text>
            <Picker
                selectedValue={value}
                onValueChange={(itemValue) => onChange(itemValue as DocumentType)}
                style={styles.picker}
            >
                {documentTypes.map((type) => (
                    <Picker.Item
                        key={type}
                        label={getDocumentTypeName(type)}
                        value={type}
                    />
                ))}
            </Picker>
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        padding: 16,
        backgroundColor: '#fff',
        borderRadius: 8,
        marginBottom: 16,
    },
    label: {
        fontSize: 14,
        fontWeight: '600',
        marginBottom: 8,
        color: '#333',
    },
    picker: {
        height: 50,
        width: '100%',
    },
});
