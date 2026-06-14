import os
import sys
import json
import keras
import tensorflow as tf
import h5py

class Logger(object):
    def __init__(self, filename="conversion_log.txt"):
        self.terminal = sys.stdout
        self.log = open(filename, "w", encoding="utf-8")

    def write(self, message):
        self.terminal.write(message)
        self.log.write(message)
        self.log.flush()

    def flush(self):
        self.terminal.flush()
        self.log.flush()

# Define the AddPositionalEmbedding custom layer
@keras.saving.register_keras_serializable(name="AddPositionalEmbedding")
class AddPositionalEmbedding(keras.layers.Layer):
    def __init__(self, num_patches, projection_dim, **kwargs):
        kwargs.pop('build_config', None)
        super(AddPositionalEmbedding, self).__init__(**kwargs)
        self.num_patches = num_patches
        self.projection_dim = projection_dim
        # Create learnable positional embedding weight
        self.pos_embedding = self.add_weight(
            name="pos_embedding",
            shape=(num_patches, projection_dim),
            initializer="random_normal",
            trainable=True
        )

    def call(self, inputs):
        return inputs + self.pos_embedding

    def get_config(self):
        config = super(AddPositionalEmbedding, self).get_config()
        config.update({
            "num_patches": self.num_patches,
            "projection_dim": self.projection_dim,
        })
        return config

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    log_path = os.path.join(script_dir, 'conversion_log.txt')
    sys.stdout = Logger(log_path)
    
    weights_path = os.path.join(script_dir, 'model.weights.h5')
    config_path = r"c:\Users\MSI\Downloads\Hybrid_model_Rice_Guard.keras\config.json"
    output_tflite_path = os.path.join(script_dir, 'assets', 'models', 'model.tflite')

    os.makedirs(os.path.dirname(output_tflite_path), exist_ok=True)

    print(f"Weights file path: {weights_path}")
    print(f"Config path: {config_path}")

    if not os.path.exists(weights_path):
        print(f"ERROR: Weights file not found at {weights_path}")
        return
    if not os.path.exists(config_path):
        print(f"ERROR: Config file not found at {config_path}")
        return

    # Load config
    config_data = None
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config_data = json.load(f)
    except Exception as e:
        print(f"ERROR: Failed to load config.json: {e}")
        return

    custom_objects = {
        "AddPositionalEmbedding": AddPositionalEmbedding
    }

    # Reconstruct architecture using Keras 3 deserialize with custom_objects
    model = None
    try:
        print("Deserializing model from config JSON using Keras 3...")
        model = keras.saving.deserialize_keras_object(config_data, custom_objects=custom_objects)
        print("SUCCESS: Model architecture reconstructed successfully.")
    except Exception as e:
        print(f"ERROR: Failed to reconstruct model architecture: {e}")
        return

    # Load weights with skip_mismatch=True
    try:
        print(f"Loading weights from {weights_path} onto the reconstructed model (skipping mismatches)...")
        model.load_weights(weights_path, skip_mismatch=True)
        print("SUCCESS: Core weights loaded successfully.")
    except Exception as e:
        print(f"ERROR loading core weights: {e}")
        return

    # Manually load the positional embedding weights
    try:
        print("Manually loading pos_embedding weights from H5 file...")
        with h5py.File(weights_path, 'r') as f:
            pos_emb_data = f['layers/add_positional_embedding/pos_embedding/vars/0'][:]
        
        # Find the positional embedding variable in the model
        pos_emb_vars = [v for v in model.variables if 'add_positional_embedding' in getattr(v, 'path', '') or 'add_positional_embedding' in v.name]
        if not pos_emb_vars:
            raise ValueError("Could not find add_positional_embedding variable in model variables.")
            
        pos_emb_var = pos_emb_vars[0]
        pos_emb_var.assign(pos_emb_data)
        print("SUCCESS: Manually loaded and assigned pos_embedding weights.")
    except Exception as e:
        print(f"ERROR manually loading pos_embedding weights: {e}")
        return

    # Step 3: Print loaded model info
    print("\n--- Model Details ---")
    print("Input shape:", model.input_shape)
    print("Output shape:", model.output_shape)
    
    # Step 4: Convert to TFLite
    print("\nConverting model to TFLite...")
    try:
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS,
            tf.lite.OpsSet.SELECT_TF_OPS
        ]
        
        tflite_model = converter.convert()
        
        with open(output_tflite_path, 'wb') as f:
            f.write(tflite_model)
        print(f"SUCCESS: Saved TFLite model to {output_tflite_path}")
        
        # Step 5: Verify the TFLite file and print details
        interpreter = tf.lite.Interpreter(model_path=output_tflite_path)
        interpreter.allocate_tensors()
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        print("\n--- TFLite Model Details ---")
        print("Input Details:")
        for detail in input_details:
            print(f"  Name: {detail['name']}, Shape: {detail['shape']}, Type: {detail['dtype']}")
        print("Output Details:")
        for detail in output_details:
            print(f"  Name: {detail['name']}, Shape: {detail['shape']}, Type: {detail['dtype']}")

    except Exception as conv_err:
        print(f"ERROR during TFLite conversion: {conv_err}")

if __name__ == '__main__':
    main()
